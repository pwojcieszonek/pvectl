# frozen_string_literal: true

require_relative "task_list"

module Pvectl
  module Repositories
    # Repository for LXC containers.
    #
    # Uses the `/cluster/resources` API endpoint to list containers across the cluster.
    # Filters to only include LXC containers (excludes QEMU VMs).
    #
    # @example Listing all containers
    #   repo = Container.new(connection)
    #   containers = repo.list
    #   containers.each { |ct| puts "#{ct.vmid}: #{ct.name}" }
    #
    # @example Listing containers on a specific node
    #   containers = repo.list(node: "pve-node1")
    #
    # @example Getting a single container
    #   ct = repo.get(100)
    #   puts ct.name if ct
    #
    # @see Pvectl::Models::Container Container model
    # @see Pvectl::Connection API connection
    #
    class Container < Base
      # Lists all containers in the cluster.
      #
      # Uses `/cluster/resources?type=lxc` endpoint for efficient cluster-wide
      # listing. Filters to only include LXC containers (type == "lxc").
      #
      # @param node [String, nil] filter by node name
      # @return [Array<Models::Container>] collection of Container models
      def list(node: nil)
        response = connection.client["cluster/resources"].get(params: { type: "vm" })
        containers = unwrap(response).select { |r| r[:type] == "lxc" }
        containers = containers.select { |r| r[:node] == node } if node
        containers.map { |data| build_model(data) }
      end

      # Gets a single container by CTID.
      #
      # @param ctid [Integer, String] container identifier
      # @return [Models::Container, nil] Container model or nil if not found
      def get(ctid)
        list.find { |ct| ct.vmid == ctid.to_i }
      end

      # Describes a container with comprehensive details from multiple API endpoints.
      #
      # @param ctid [Integer, String] container identifier
      # @return [Models::Container, nil] Container model with full details, or nil if not found
      def describe(ctid)
        ctid = ctid.to_i

        basic_data = find_container_basic_data(ctid)
        return nil if basic_data.nil?

        node = basic_data[:node]

        config = fetch_config(node, ctid)
        status = fetch_status(node, ctid)
        snapshots = fetch_snapshots(node, ctid)
        tasks = fetch_tasks(node, ctid)

        build_describe_model(basic_data, config, status, snapshots, tasks)
      end

      # Deletes a container from the cluster.
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @param destroy_disks [Boolean] destroy unreferenced disks (default: true)
      # @param purge [Boolean] remove from HA, replication, backups (default: false)
      # @param force [Boolean] force removal (default: false)
      # @return [String] Task UPID
      def delete(ctid, node, destroy_disks: true, purge: false, force: false)
        params = {}
        params["destroy-unreferenced-disks"] = 1 if destroy_disks
        params[:purge] = 1 if purge
        params[:force] = 1 if force

        connection.client["nodes/#{node}/lxc/#{ctid}"].delete(params)
      end

      # Starts a container.
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def start(ctid, node)
        connection.client["nodes/#{node}/lxc/#{ctid}/status/start"].post
      end

      # Stops a container (hard stop).
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def stop(ctid, node)
        connection.client["nodes/#{node}/lxc/#{ctid}/status/stop"].post
      end

      # Shuts down a container gracefully.
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def shutdown(ctid, node)
        connection.client["nodes/#{node}/lxc/#{ctid}/status/shutdown"].post
      end

      # Clones a container to create a new container.
      #
      # Posts to `/nodes/{node}/lxc/{ctid}/clone` with the specified parameters.
      # Note: LXC API uses `hostname` parameter (not `name` like QEMU).
      #
      # @param ctid [Integer, String] source container identifier
      # @param node [String] source node name
      # @param new_ctid [Integer] CTID for the new cloned container
      # @param options [Hash] optional clone parameters
      # @option options [String] :hostname hostname for the new container
      # @option options [String] :target target node for the clone
      # @option options [String] :storage target storage for the clone
      # @option options [Boolean] :full full clone (true) or linked clone (false)
      # @option options [String] :description description for the new container
      # @option options [String] :pool resource pool for the new container
      # @return [String] Task UPID
      def clone(ctid, node, new_ctid, options = {})
        params = { newid: new_ctid }
        params[:hostname] = options[:hostname] if options[:hostname]
        params[:target] = options[:target] if options[:target]
        params[:storage] = options[:storage] if options[:storage]
        params[:full] = options[:full] ? 1 : 0 if options.key?(:full)
        params[:description] = options[:description] if options[:description]
        params[:pool] = options[:pool] if options[:pool]

        connection.client["nodes/#{node}/lxc/#{ctid}/clone"].post(params)
      end

      # Converts a container to a template.
      #
      # This is an irreversible operation. The container will become read-only
      # and can only be used as a source for cloning.
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [void]
      def convert_to_template(ctid, node)
        connection.client["nodes/#{node}/lxc/#{ctid}/template"].post({})
      end

      # Migrates a container to another node.
      #
      # @param ctid [Integer, String] container identifier
      # @param node [String] current node name
      # @param params [Hash] migration parameters (:target, :online, :restart, :targetstorage)
      # @return [String] Task UPID
      # @raise [ArgumentError] if node name or ctid format is invalid
      def migrate(ctid, node, params = {})
        unless node.match?(/\A[a-z][a-z0-9-]*\z/)
          raise ArgumentError, "Invalid node name: #{node}"
        end
        unless ctid.is_a?(Integer) && ctid.positive?
          raise ArgumentError, "Invalid CTID: #{ctid}"
        end

        connection.client["nodes/#{node}/lxc/#{ctid}/migrate"].post(params)
      end

      # Finds the next available CTID starting from a minimum value.
      #
      # Scans existing containers and returns the lowest unused CTID at or above
      # the specified minimum.
      #
      # @param min [Integer] minimum CTID to consider (default: 100)
      # @return [Integer] next available CTID
      def next_available_ctid(min: 100)
        used_ids = list.map(&:vmid).to_set
        ctid = min
        ctid += 1 while used_ids.include?(ctid)
        ctid
      end

      # Restarts a container (reboot).
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def restart(ctid, node)
        connection.client["nodes/#{node}/lxc/#{ctid}/status/reboot"].post
      end

      # Opens a terminal proxy session for a container.
      #
      # @param ctid [Integer, String] Container identifier
      # @param node [String] Node name
      # @return [Hash] termproxy data with :port, :ticket, :user keys
      def termproxy(ctid, node)
        response = connection.client["nodes/#{node}/lxc/#{ctid}/termproxy"].post({})
        extract_data(response)
      end

      # Creates a new LXC container on the specified node.
      #
      # Posts to `/nodes/{node}/lxc` with the container configuration parameters.
      # The ctid is merged into params automatically.
      #
      # @param node [String] target node name
      # @param ctid [Integer] container identifier
      # @param params [Hash] container configuration parameters (hostname, ostemplate, etc.)
      # @return [String] Task UPID
      #
      # @example Create a basic container
      #   repo.create("pve1", 200, { hostname: "web-ct", ostemplate: "local:vztmpl/debian-12.tar.zst" })
      #   #=> "UPID:pve1:..."
      def create(node, ctid, params = {})
        api_params = params.merge(vmid: ctid)
        connection.client["nodes/#{node}/lxc"].post(api_params)
      end

      # Updates an existing LXC container configuration.
      #
      # PUTs to +/nodes/{node}/lxc/{ctid}/config+ with configuration parameters.
      # This is a synchronous operation — changes are applied immediately.
      #
      # @param ctid [Integer, String] container identifier
      # @param node [String] node name
      # @param params [Hash] container configuration parameters to update
      # @return [nil]
      def update(ctid, node, params = {})
        connection.client["nodes/#{node}/lxc/#{ctid}/config"].put(params)
      end

      # Resizes a container disk.
      #
      # PUTs to +/nodes/{node}/lxc/{ctid}/resize+ with disk identifier
      # and new size. This is a synchronous, irreversible operation —
      # Proxmox does not support shrinking disks.
      #
      # @param ctid [Integer, String] container identifier
      # @param node [String] node name
      # @param disk [String] disk identifier (e.g., "rootfs", "mp0")
      # @param size [String] new size, absolute ("50G") or relative ("+10G")
      # @return [nil]
      def resize(ctid, node, disk:, size:)
        connection.client["nodes/#{node}/lxc/#{ctid}/resize"].put({ disk: disk, size: size })
      end

      # Fetches container configuration.
      #
      # @param node [String] node name
      # @param ctid [Integer] container identifier
      # @return [Hash] config data
      def fetch_config(node, ctid)
        resp = connection.client["nodes/#{node}/lxc/#{ctid}/config"].get
        extract_data(resp)
      rescue StandardError
        {}
      end

      protected

      # Builds Container model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::Container] Container model instance
      def build_model(data)
        Models::Container.new(
          vmid: data[:vmid],
          name: data[:name],
          status: data[:status],
          node: data[:node],
          cpu: data[:cpu],
          maxcpu: data[:maxcpu],
          mem: data[:mem],
          maxmem: data[:maxmem],
          swap: data[:swap],
          maxswap: data[:maxswap],
          disk: data[:disk],
          maxdisk: data[:maxdisk],
          uptime: data[:uptime],
          template: data[:template],
          tags: data[:tags],
          pool: data[:pool],
          lock: data[:lock],
          netin: data[:netin],
          netout: data[:netout],
          type: data[:type]
        )
      end

      private

      # Finds container basic data from cluster resources.
      #
      # @param ctid [Integer] container identifier
      # @return [Hash, nil] container data or nil if not found
      def find_container_basic_data(ctid)
        response = connection.client["cluster/resources"].get(params: { type: "vm" })
        unwrap(response).find { |r| r[:type] == "lxc" && r[:vmid] == ctid }
      end

      # Fetches container runtime status.
      #
      # @param node [String] node name
      # @param ctid [Integer] container identifier
      # @return [Hash] status data
      def fetch_status(node, ctid)
        resp = connection.client["nodes/#{node}/lxc/#{ctid}/status/current"].get
        extract_data(resp)
      rescue StandardError
        {}
      end

      # Fetches container snapshots.
      #
      # @param node [String] node name
      # @param ctid [Integer] container identifier
      # @return [Array<Hash>] snapshots list (excluding "current")
      def fetch_snapshots(node, ctid)
        resp = connection.client["nodes/#{node}/lxc/#{ctid}/snapshot"].get
        unwrap(resp).reject { |s| s[:name] == "current" }
      rescue StandardError
        []
      end

      # Fetches recent task history for the container.
      #
      # @param node [String] node name
      # @param ctid [Integer] container identifier
      # @param limit [Integer] max entries (default 10)
      # @return [Array<Models::TaskEntry>] recent tasks
      def fetch_tasks(node, ctid, limit: 10)
        task_list_repo = TaskList.new(connection)
        task_list_repo.list(node: node, vmid: ctid, limit: limit)
      rescue StandardError
        []
      end

      # Extracts network interfaces from config.
      # Network interfaces are stored as net0, net1, etc. keys.
      #
      # @param config [Hash] container config
      # @return [Array<Hash>] parsed network interfaces
      def extract_network_interfaces(config)
        interfaces = []
        config.each do |key, value|
          next unless key.to_s.match?(/^net\d+$/)

          parsed = parse_network_interface(key.to_s, value)
          interfaces << parsed if parsed
        end
        interfaces
      end

      # Parses a single network interface string.
      #
      # @param key [String] interface key (e.g., "net0")
      # @param value [String] interface configuration string
      # @return [Hash] parsed interface data
      def parse_network_interface(key, value)
        return nil unless value.is_a?(String)

        interface = { id: key }

        # Parse key=value pairs from the interface string
        value.split(",").each do |part|
          k, v = part.split("=", 2)
          interface[k.to_sym] = v if k && v
        end

        interface
      end

      # Builds Container model with describe-specific attributes.
      #
      # @param basic_data [Hash] basic container data from cluster/resources
      # @param config [Hash] container config from /nodes/{node}/lxc/{ctid}/config
      # @param status [Hash] container status from /nodes/{node}/lxc/{ctid}/status/current
      # @param snapshots [Array<Hash>] container snapshots
      # @return [Models::Container] Container model
      def build_describe_model(basic_data, config, status, snapshots = [], tasks = [])
        network_interfaces = extract_network_interfaces(config)

        Models::Container.new(
          # Basic attributes from cluster/resources
          vmid: basic_data[:vmid],
          name: basic_data[:name],
          status: basic_data[:status],
          node: basic_data[:node],
          type: basic_data[:type],
          cpu: basic_data[:cpu],
          maxcpu: basic_data[:maxcpu],
          mem: basic_data[:mem],
          maxmem: basic_data[:maxmem],
          swap: basic_data[:swap],
          maxswap: basic_data[:maxswap],
          disk: basic_data[:disk],
          maxdisk: basic_data[:maxdisk],
          uptime: basic_data[:uptime],
          template: basic_data[:template],
          tags: basic_data[:tags],
          pool: basic_data[:pool],
          lock: basic_data[:lock],
          netin: basic_data[:netin],
          netout: basic_data[:netout],

          # Config attributes (kept for backward compat)
          ostype: config[:ostype],
          arch: config[:arch],
          unprivileged: config[:unprivileged],
          features: config[:features],
          rootfs: config[:rootfs],
          description: config[:description],
          hostname: config[:hostname],

          # Status attributes
          pid: status[:pid],
          ha: status[:ha],

          # Parsed network interfaces
          network_interfaces: network_interfaces,

          # Raw API data for comprehensive describe
          describe_data: { config: config, status: status, snapshots: snapshots, tasks: tasks }
        )
      end
    end
  end
end
