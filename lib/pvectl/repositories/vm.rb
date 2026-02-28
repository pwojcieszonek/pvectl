# frozen_string_literal: true

require "set"
require_relative "task_list"

module Pvectl
  module Repositories
    # Repository for QEMU virtual machines.
    #
    # Uses the `/cluster/resources` API endpoint to list VMs across the cluster.
    # Filters to only include QEMU VMs (excludes LXC containers).
    #
    # @example Listing all VMs
    #   repo = Vm.new(connection)
    #   vms = repo.list
    #   vms.each { |vm| puts "#{vm.vmid}: #{vm.name}" }
    #
    # @example Listing VMs on a specific node
    #   vms = repo.list(node: "pve-node1")
    #
    # @example Getting a single VM
    #   vm = repo.get(100)
    #   puts vm.name if vm
    #
    # @see Pvectl::Models::Vm VM model
    # @see Pvectl::Connection API connection
    #
    class Vm < Base
      # Lists all VMs in the cluster.
      #
      # Uses `/cluster/resources?type=vm` endpoint for efficient cluster-wide
      # listing. Filters to only include QEMU VMs (type == "qemu").
      #
      # @param node [String, nil] filter by node name
      # @return [Array<Models::Vm>] collection of VM models
      def list(node: nil)
        response = connection.client["cluster/resources"].get(params: { type: "vm" })
        vms = response.select { |r| r[:type] == "qemu" }
        vms = vms.select { |r| r[:node] == node } if node
        vms.map { |data| build_model(data) }
      end

      # Gets a single VM by VMID.
      #
      # @param vmid [Integer, String] VM identifier
      # @return [Models::Vm, nil] VM model or nil if not found
      def get(vmid)
        list.find { |vm| vm.vmid == vmid.to_i }
      end

      # Describes a VM with comprehensive details from multiple API endpoints.
      #
      # @param vmid [Integer, String] VM identifier
      # @return [Models::Vm, nil] VM model with full details, or nil if not found
      def describe(vmid)
        vmid = vmid.to_i

        # 1. Find VM in cluster to get node
        basic_data = find_vm_basic_data(vmid)
        return nil if basic_data.nil?

        node = basic_data[:node]

        # 2. Fetch detailed data from node-specific endpoints
        describe_data = {
          config: fetch_config(node, vmid),
          status: fetch_status(node, vmid),
          snapshots: fetch_snapshots(node, vmid),
          agent_ips: fetch_agent_ips(node, vmid),
          pending: fetch_pending(node, vmid),
          tasks: fetch_tasks(node, vmid),
          firewall: fetch_firewall(node, vmid)
        }

        build_describe_model(basic_data, describe_data)
      end

      # ---------------------------
      # Lifecycle Operations
      # ---------------------------

      # Starts a VM.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def start(vmid, node)
        post_status(vmid, node, "start")
      end

      # Stops a VM immediately (hard stop).
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def stop(vmid, node)
        post_status(vmid, node, "stop")
      end

      # Shuts down a VM gracefully (ACPI).
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def shutdown(vmid, node)
        post_status(vmid, node, "shutdown")
      end

      # Restarts a VM (reboot).
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def restart(vmid, node)
        post_status(vmid, node, "reboot")
      end

      # Resets a VM (hard reset).
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def reset(vmid, node)
        post_status(vmid, node, "reset")
      end

      # Suspends a VM (hibernate).
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def suspend(vmid, node)
        post_status(vmid, node, "suspend")
      end

      # Resumes a suspended VM.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [String] Task UPID
      def resume(vmid, node)
        post_status(vmid, node, "resume")
      end

      # Opens a terminal proxy session for a VM.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @return [Hash] termproxy data with :port, :ticket, :user keys
      def termproxy(vmid, node)
        response = connection.client["nodes/#{node}/qemu/#{vmid}/termproxy"].post({})
        normalize_hash_response(response)
      end

      # Deletes a VM from the cluster.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @param destroy_disks [Boolean] destroy unreferenced disks (default: true)
      # @param purge [Boolean] remove from HA, replication, backups (default: false)
      # @param force [Boolean] skip lock (default: false)
      # @return [String] Task UPID
      def delete(vmid, node, destroy_disks: true, purge: false, force: false)
        params = {}
        params["destroy-unreferenced-disks"] = 1 if destroy_disks
        params[:purge] = 1 if purge
        params[:skiplock] = 1 if force

        connection.client["nodes/#{node}/qemu/#{vmid}"].delete(params)
      end

      # Clones a VM to create a new VM.
      #
      # Posts to `/nodes/{node}/qemu/{vmid}/clone` with the specified parameters.
      #
      # @param vmid [Integer, String] source VM identifier
      # @param node [String] source node name
      # @param new_vmid [Integer] VMID for the new cloned VM
      # @param options [Hash] optional clone parameters
      # @option options [String] :name name for the new VM
      # @option options [String] :target target node for the clone
      # @option options [String] :storage target storage for the clone
      # @option options [Boolean] :full full clone (true) or linked clone (false)
      # @option options [String] :description description for the new VM
      # @option options [String] :pool resource pool for the new VM
      # @return [String] Task UPID
      def clone(vmid, node, new_vmid, options = {})
        params = { newid: new_vmid }
        params[:name] = options[:name] if options[:name]
        params[:target] = options[:target] if options[:target]
        params[:storage] = options[:storage] if options[:storage]
        params[:full] = options[:full] ? 1 : 0 if options.key?(:full)
        params[:description] = options[:description] if options[:description]
        params[:pool] = options[:pool] if options[:pool]

        connection.client["nodes/#{node}/qemu/#{vmid}/clone"].post(params)
      end

      # Converts a VM to a template.
      #
      # This is an irreversible operation. The VM will become read-only
      # and can only be used as a source for cloning.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @param disk [String, nil] specific disk to convert (e.g., "scsi0")
      # @return [void]
      def convert_to_template(vmid, node, disk: nil)
        params = {}
        params[:disk] = disk if disk
        connection.client["nodes/#{node}/qemu/#{vmid}/template"].post(params)
      end

      # Creates a new VM on the specified node.
      #
      # Posts to `/nodes/{node}/qemu` with the VM configuration parameters.
      # The vmid is merged into params automatically.
      #
      # @param node [String] target node name
      # @param vmid [Integer] VM identifier
      # @param params [Hash] VM configuration parameters (name, cores, memory, etc.)
      # @return [String] Task UPID
      #
      # @example Create a basic VM
      #   repo.create("pve1", 100, { name: "web-server", cores: 4, memory: 4096 })
      #   #=> "UPID:pve1:..."
      def create(node, vmid, params = {})
        api_params = params.merge(vmid: vmid)
        connection.client["nodes/#{node}/qemu"].post(api_params)
      end

      # Updates an existing VM configuration.
      #
      # PUTs to +/nodes/{node}/qemu/{vmid}/config+ with configuration parameters.
      # This is a synchronous operation — changes are applied immediately.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] node name
      # @param params [Hash] VM configuration parameters to update
      # @return [nil]
      def update(vmid, node, params = {})
        connection.client["nodes/#{node}/qemu/#{vmid}/config"].put(params)
      end

      # Resizes a VM disk.
      #
      # PUTs to +/nodes/{node}/qemu/{vmid}/resize+ with disk and size parameters.
      # Size can be absolute (e.g., "50G") or relative (e.g., "+10G").
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] node name
      # @param disk [String] disk name (e.g., "scsi0", "virtio0")
      # @param size [String] new size or size increment (e.g., "50G", "+10G")
      # @return [nil]
      def resize(vmid, node, disk:, size:)
        connection.client["nodes/#{node}/qemu/#{vmid}/resize"].put({ disk: disk, size: size })
      end

      # Fetches VM configuration.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Hash] config data
      def fetch_config(node, vmid)
        resp = connection.client["nodes/#{node}/qemu/#{vmid}/config"].get
        normalize_hash_response(resp)
      rescue StandardError
        {}
      end

      # Migrates a VM to another node.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] current node name
      # @param params [Hash] migration parameters (:target, :online, :"with-local-disks", :targetstorage)
      # @return [String] Task UPID
      # @raise [ArgumentError] if node name or vmid format is invalid
      def migrate(vmid, node, params = {})
        unless node.match?(/\A[a-z][a-z0-9-]*\z/)
          raise ArgumentError, "Invalid node name: #{node}"
        end
        unless vmid.is_a?(Integer) && vmid.positive?
          raise ArgumentError, "Invalid VMID: #{vmid}"
        end

        connection.client["nodes/#{node}/qemu/#{vmid}/migrate"].post(params)
      end

      # Finds the next available VMID starting from a minimum value.
      #
      # Scans existing VMs and returns the lowest unused VMID at or above the
      # specified minimum.
      #
      # @param min [Integer] minimum VMID to consider (default: 100)
      # @return [Integer] next available VMID
      def next_available_vmid(min: 100)
        used_ids = list.map(&:vmid).to_set
        vmid = min
        vmid += 1 while used_ids.include?(vmid)
        vmid
      end

      protected

      # Builds Vm model from API response data.
      #
      # @param data [Hash] API response hash with string keys
      # @return [Models::Vm] VM model instance
      def build_model(data)
        Models::Vm.new(
          vmid: data[:vmid],
          name: data[:name],
          status: data[:status],
          node: data[:node],
          cpu: data[:cpu],
          maxcpu: data[:maxcpu],
          mem: data[:mem],
          maxmem: data[:maxmem],
          disk: data[:disk],
          maxdisk: data[:maxdisk],
          uptime: data[:uptime],
          template: data[:template],
          tags: data[:tags],
          hastate: data[:hastate],
          netin: data[:netin],
          netout: data[:netout],
          type: data[:type]
        )
      end

      private

      # Posts to VM status endpoint.
      #
      # @param vmid [Integer, String] VM identifier
      # @param node [String] Node name
      # @param action [String] Action (start, stop, etc.)
      # @return [String] Task UPID
      def post_status(vmid, node, action)
        connection.client["nodes/#{node}/qemu/#{vmid}/status/#{action}"].post
      end

      # Finds VM basic data from cluster resources.
      #
      # @param vmid [Integer] VM identifier
      # @return [Hash, nil] VM data or nil if not found
      def find_vm_basic_data(vmid)
        response = connection.client["cluster/resources"].get(params: { type: "vm" })
        response.find { |r| r[:type] == "qemu" && r[:vmid] == vmid }
      end

      # Fetches VM runtime status.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Hash] status data
      def fetch_status(node, vmid)
        resp = connection.client["nodes/#{node}/qemu/#{vmid}/status/current"].get
        normalize_hash_response(resp)
      rescue StandardError
        {}
      end

      # Fetches VM snapshots.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Array<Hash>] snapshots list
      def fetch_snapshots(node, vmid)
        resp = connection.client["nodes/#{node}/qemu/#{vmid}/snapshot"].get
        normalize_response(resp).reject { |s| s[:name] == "current" }
      rescue StandardError
        []
      end

      # Fetches IP addresses from QEMU guest agent.
      # Graceful failure - returns nil on any error.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Array<Hash>, nil] interfaces or nil on error
      def fetch_agent_ips(node, vmid)
        resp = connection.client["nodes/#{node}/qemu/#{vmid}/agent/network-get-interfaces"].get
        data = normalize_hash_response(resp)
        data[:result]
      rescue StandardError
        nil
      end

      # Fetches pending configuration changes.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Array<Hash>] pending changes
      def fetch_pending(node, vmid)
        resp = connection.client["nodes/#{node}/qemu/#{vmid}/pending"].get
        normalize_response(resp)
      rescue StandardError
        []
      end

      # Fetches firewall configuration (options, rules, aliases, IP sets).
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @return [Hash] firewall data with :options, :rules, :aliases, :ipset keys
      def fetch_firewall(node, vmid)
        base = "nodes/#{node}/qemu/#{vmid}/firewall"
        {
          options: normalize_hash_response(connection.client["#{base}/options"].get),
          rules: normalize_response(connection.client["#{base}/rules"].get),
          aliases: normalize_response(connection.client["#{base}/aliases"].get),
          ipset: normalize_response(connection.client["#{base}/ipset"].get)
        }
      rescue StandardError
        {}
      end

      # Fetches recent task history for the VM.
      #
      # @param node [String] node name
      # @param vmid [Integer] VM identifier
      # @param limit [Integer] max entries (default 10)
      # @return [Array<Models::TaskEntry>] recent tasks
      def fetch_tasks(node, vmid, limit: 10)
        task_list_repo = TaskList.new(connection)
        task_list_repo.list(node: node, vmid: vmid, limit: limit)
      rescue StandardError
        []
      end

      # Normalizes hash response that may be wrapped in :data key.
      #
      # @param response [Hash] API response
      # @return [Hash] normalized hash
      def normalize_hash_response(response)
        if response.is_a?(Hash) && response[:data]
          response[:data]
        else
          response || {}
        end
      end

      # Normalizes array response.
      #
      # @param response [Array, Hash] API response
      # @return [Array<Hash>] normalized array
      def normalize_response(response)
        if response.is_a?(Array)
          response
        elsif response.is_a?(Hash) && response[:data]
          response[:data]
        else
          response.to_a
        end
      end

      # Builds VM model with describe-specific attributes.
      #
      # @param basic_data [Hash] basic VM data from cluster/resources
      # @param describe_data [Hash] aggregated describe data
      # @return [Models::Vm] VM model
      def build_describe_model(basic_data, describe_data)
        Models::Vm.new(
          vmid: basic_data[:vmid],
          name: basic_data[:name],
          status: basic_data[:status],
          node: basic_data[:node],
          cpu: basic_data[:cpu],
          maxcpu: basic_data[:maxcpu],
          mem: basic_data[:mem],
          maxmem: basic_data[:maxmem],
          disk: basic_data[:disk],
          maxdisk: basic_data[:maxdisk],
          uptime: basic_data[:uptime],
          template: basic_data[:template],
          tags: basic_data[:tags],
          hastate: basic_data[:hastate],
          netin: basic_data[:netin],
          netout: basic_data[:netout],
          type: basic_data[:type],
          describe_data: describe_data
        )
      end
    end
  end
end
