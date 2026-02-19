# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox cluster nodes.
    #
    # Uses the `/nodes` API endpoint to list nodes.
    # Optionally fetches additional details from per-node endpoints.
    #
    # @example Listing all nodes
    #   repo = Node.new(connection)
    #   nodes = repo.list
    #   nodes.each { |n| puts "#{n.name}: #{n.status}" }
    #
    # @example Getting node with extended details
    #   node = repo.get("pve-node1", include_details: true)
    #
    # @see Pvectl::Models::Node Node model
    # @see Pvectl::Connection API connection
    #
    class Node < Base
      # Creates a new Node repository.
      #
      # @param connection [Connection] API connection
      # @param storage_repository [Repositories::Storage, nil] optional storage repository for DI
      def initialize(connection, storage_repository: nil)
        super(connection)
        @storage_repository = storage_repository
      end

      # Lists all nodes in the cluster.
      #
      # @param include_details [Boolean] fetch version/status details (extra API calls)
      # @return [Array<Models::Node>] collection of Node models
      def list(include_details: false)
        response = connection.client["nodes"].get
        nodes_data = unwrap(response)

        # Get guest counts from cluster/resources
        guest_counts = guest_counts_for_cluster

        nodes_data.map do |data|
          node_name = data[:node] || data[:name]

          # Merge guest counts
          data = data.merge(
            guests_vms: guest_counts.dig(node_name, :vms) || 0,
            guests_cts: guest_counts.dig(node_name, :cts) || 0
          )

          # Fetch extended details if requested
          if include_details && (data[:status] == "online")
            data = data.merge(details_for(node_name))
          end

          build_model(data)
        end
      end

      # Gets a single node by name.
      #
      # @param name [String] node name
      # @param include_details [Boolean] fetch version/status details
      # @return [Models::Node, nil] Node model or nil if not found
      def get(name, include_details: false)
        list(include_details: include_details).find { |n| n.name == name }
      end

      # Describes a node with comprehensive details from multiple API endpoints.
      #
      # @param name [String] node name
      # @return [Models::Node, nil] Node model with full details, or nil if not found
      def describe(name)
        # First check if node exists in cluster
        nodes_data = unwrap(connection.client["nodes"].get)
        basic_data = nodes_data.find { |n| (n[:node] || n[:name]) == name }
        return nil if basic_data.nil?

        # Merge guest counts
        guest_counts = guest_counts_for_cluster
        data = basic_data.merge(
          guests_vms: guest_counts.dig(name, :vms) || 0,
          guests_cts: guest_counts.dig(name, :cts) || 0
        )

        # For offline nodes, return basic data with offline note
        unless basic_data[:status] == "online"
          data[:offline_note] = "Node offline - detailed metrics unavailable"
          return build_describe_model(data)
        end

        # Fetch comprehensive details
        data = data.merge(describe_details_for(name))

        build_describe_model(data)
      end

      protected

      # Builds Node model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::Node] Node model instance
      def build_model(data)
        Models::Node.new(
          name: data[:node] || data[:name],
          status: data[:status],
          cpu: data[:cpu],
          maxcpu: data[:maxcpu],
          mem: data[:mem],
          maxmem: data[:maxmem],
          disk: data[:disk],
          maxdisk: data[:maxdisk],
          uptime: data[:uptime],
          level: data[:level],
          version: data[:version],
          kernel: data[:kernel],
          loadavg: data[:loadavg],
          swap_used: data[:swap_used],
          swap_total: data[:swap_total],
          guests_vms: data[:guests_vms],
          guests_cts: data[:guests_cts],
          ip: data[:ip]
        )
      end

      private

      # Fetches guest counts per node from cluster/resources.
      #
      # @return [Hash] { "node_name" => { vms: N, cts: M } }
      def guest_counts_for_cluster
        response = connection.client["cluster/resources"].get(params: { type: "vm" })
        resources = unwrap(response)

        counts = Hash.new { |h, k| h[k] = { vms: 0, cts: 0 } }
        resources.each do |r|
          node = r[:node]
          next if node.nil?

          if r[:type] == "qemu"
            counts[node][:vms] += 1
          elsif r[:type] == "lxc"
            counts[node][:cts] += 1
          end
        end
        counts
      end

      # Fetches extended details for a node (version, status).
      #
      # @param node_name [String] node name
      # @return [Hash] merged version and status data
      def details_for(node_name)
        result = {}

        # Fetch version
        begin
          version_resp = connection.client["nodes/#{node_name}/version"].get
          version_data = extract_data(version_resp)
          result[:version] = version_data[:version]
          result[:kernel] = version_data[:kernel]
        rescue StandardError
          # Ignore errors fetching version
        end

        # Fetch status (for load, swap)
        begin
          status_resp = connection.client["nodes/#{node_name}/status"].get
          status_data = extract_data(status_resp)
          result[:loadavg] = status_data[:loadavg]&.map(&:to_f)
          result[:kernel] ||= extract_kernel_version(status_data[:kversion])
          if status_data[:swap]
            result[:swap_used] = status_data[:swap][:used]
            result[:swap_total] = status_data[:swap][:total]
          end
        rescue StandardError
          # Ignore errors fetching status
        end

        # Fetch network (for IP)
        result[:ip] = ip_for(node_name)

        result
      end

      # Fetches IP address from node network configuration.
      #
      # Finds the first interface with a gateway configured (default route)
      # and extracts its IP address.
      #
      # @param node_name [String] node name
      # @return [String, nil] IP address or nil if unavailable
      def ip_for(node_name)
        network_resp = connection.client["nodes/#{node_name}/network"].get
        interfaces = unwrap(network_resp)
        extract_ip_from_network(interfaces)
      rescue StandardError
        nil
      end

      # Extracts IP from network interfaces.
      #
      # Algorithm (KISS):
      # 1. Find first interface with non-empty `gateway` field
      # 2. Extract IP from `address` field
      # 3. Remove CIDR suffix if present (e.g., "192.168.1.10/24" -> "192.168.1.10")
      #
      # @param interfaces [Array<Hash>] network interfaces from API
      # @return [String, nil] IP address or nil
      def extract_ip_from_network(interfaces)
        return nil if interfaces.nil? || interfaces.empty?

        # Find first interface with gateway (default route interface)
        iface = interfaces.find { |i| i[:gateway] && !i[:gateway].to_s.empty? }
        return nil unless iface

        # Extract IP, removing CIDR suffix if present
        address = iface[:address] || iface[:cidr]
        return nil if address.nil? || address.to_s.empty?

        address.to_s.split("/").first
      end

      # Extracts kernel version from kversion string.
      #
      # The kversion string from Proxmox API looks like:
      #   "Linux 6.8.12-1-pve #1 SMP PREEMPT_DYNAMIC..."
      # This method extracts just the version: "6.8.12-1-pve"
      #
      # @param kversion [String, nil] full kernel version string
      # @return [String, nil] extracted kernel version or nil
      def extract_kernel_version(kversion)
        return nil if kversion.nil? || kversion.empty?

        # Match pattern: "Linux X.Y.Z-something ..."
        match = kversion.match(/Linux\s+([\d.]+-[\w.-]+)/)
        match ? match[1] : kversion
      end

      # Fetches comprehensive details for describe command.
      # Reuses existing helper methods where possible.
      #
      # @param node_name [String] node name
      # @return [Hash] aggregated data from multiple endpoints
      def describe_details_for(node_name)
        result = {}

        # Reuse existing details_for for version/status/network
        result.merge!(details_for(node_name))

        # Additional describe-specific endpoints
        result.merge!(subscription_for(node_name))
        result.merge!(dns_for(node_name))
        result.merge!(time_for(node_name))
        result.merge!(services_for(node_name))
        result.merge!(storage_pools_for(node_name))
        result.merge!(disks_for(node_name))
        result.merge!(qemu_cpu_for(node_name))
        result.merge!(qemu_machines_for(node_name))
        result.merge!(updates_for(node_name))
        result.merge!(extended_status_for(node_name))

        result
      end

      # Fetches subscription info for a node.
      #
      # Filters sensitive fields (license key) to prevent accidental exposure.
      # Only safe display data is returned.
      #
      # @param node_name [String] node name
      # @return [Hash] subscription data (filtered for safety)
      def subscription_for(node_name)
        resp = connection.client["nodes/#{node_name}/subscription"].get
        data = extract_data(resp)
        # Filter sensitive fields - keep only safe display data
        safe_data = {
          status: data[:status],
          level: data[:level],
          productname: data[:productname],
          regdate: data[:regdate],
          checktime: data[:checktime]
        }
        { subscription: safe_data }
      rescue StandardError
        { subscription: nil }
      end

      # Fetches DNS configuration for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] DNS data
      def dns_for(node_name)
        resp = connection.client["nodes/#{node_name}/dns"].get
        data = extract_data(resp)
        { dns: data }
      rescue StandardError
        { dns: nil }
      end

      # Fetches time configuration for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] time data
      def time_for(node_name)
        resp = connection.client["nodes/#{node_name}/time"].get
        data = extract_data(resp)
        { time_info: data }
      rescue StandardError
        { time_info: nil }
      end

      # Fetches services for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] services data (raw hashes, not models - used in describe)
      def services_for(node_name)
        resp = connection.client["nodes/#{node_name}/services"].get
        { services: unwrap(resp) }
      rescue StandardError
        { services: [] }
      end

      # Fetches storage pools for a node.
      #
      # Delegates to Repositories::Storage#list_for_node for consistent
      # model creation and DRY compliance.
      #
      # @param node_name [String] node name
      # @return [Hash] storage pools data with Array<Models::Storage>
      def storage_pools_for(node_name)
        { storage_pools: storage_repository.list_for_node(node_name) }
      rescue StandardError
        { storage_pools: [] }
      end

      # Returns storage repository instance.
      # Uses injected repository if provided, otherwise creates new one.
      #
      # @return [Repositories::Storage] storage repository
      def storage_repository
        @storage_repository ||= Repositories::Storage.new(connection)
      end

      # Fetches physical disks for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] disks data (raw hashes, not models - used in describe)
      def disks_for(node_name)
        resp = connection.client["nodes/#{node_name}/disks/list"].get
        { physical_disks: unwrap(resp) }
      rescue StandardError
        { physical_disks: [] }
      end

      # Fetches QEMU CPU models for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] QEMU CPU models
      def qemu_cpu_for(node_name)
        resp = connection.client["nodes/#{node_name}/capabilities/qemu/cpu"].get
        { qemu_cpu_models: unwrap(resp) }
      rescue StandardError
        { qemu_cpu_models: [] }
      end

      # Fetches QEMU machine types for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] QEMU machine types
      def qemu_machines_for(node_name)
        resp = connection.client["nodes/#{node_name}/capabilities/qemu/machines"].get
        { qemu_machines: unwrap(resp) }
      rescue StandardError
        { qemu_machines: [] }
      end

      # Fetches available updates for a node.
      #
      # @param node_name [String] node name
      # @return [Hash] updates data
      def updates_for(node_name)
        resp = connection.client["nodes/#{node_name}/apt/versions"].get
        packages = unwrap(resp)
        upgradable = packages.select do |p|
          p[:AvailableVersion] && p[:AvailableVersion] != p[:CurrentVersion]
        end
        { updates_available: upgradable.size, updates: upgradable }
      rescue StandardError
        { updates_available: 0, updates: [] }
      end

      # Fetches extended status (cpuinfo, boot_info, rootfs, network_interfaces).
      #
      # @param node_name [String] node name
      # @return [Hash] extended status data
      def extended_status_for(node_name)
        resp = connection.client["nodes/#{node_name}/status"].get
        data = extract_data(resp)
        {
          cpuinfo: data[:cpuinfo],
          boot_info: data[:"boot-info"],
          rootfs: data[:rootfs],
          network_interfaces: network_interfaces_for(node_name)
        }
      rescue StandardError
        {}
      end

      # Fetches network interfaces for a node.
      #
      # @param node_name [String] node name
      # @return [Array<Hash>] network interfaces (raw hashes for describe output)
      def network_interfaces_for(node_name)
        resp = connection.client["nodes/#{node_name}/network"].get
        unwrap(resp)
      rescue StandardError
        []
      end

      # Builds Node model with describe-specific attributes.
      #
      # @param data [Hash] aggregated data from API
      # @return [Models::Node] Node model
      def build_describe_model(data)
        Models::Node.new(
          # Basic fields (existing)
          name: data[:node] || data[:name],
          status: data[:status],
          cpu: data[:cpu],
          maxcpu: data[:maxcpu],
          mem: data[:mem],
          maxmem: data[:maxmem],
          disk: data[:disk],
          maxdisk: data[:maxdisk],
          uptime: data[:uptime],
          level: data[:level],
          version: data[:version],
          kernel: data[:kernel],
          loadavg: data[:loadavg],
          swap_used: data[:swap_used],
          swap_total: data[:swap_total],
          guests_vms: data[:guests_vms],
          guests_cts: data[:guests_cts],
          ip: data[:ip],
          # Extended fields for describe
          cpuinfo: data[:cpuinfo],
          boot_info: data[:boot_info],
          rootfs: data[:rootfs],
          subscription: data[:subscription],
          dns: data[:dns],
          time_info: data[:time_info],
          network_interfaces: data[:network_interfaces],
          services: data[:services],
          storage_pools: data[:storage_pools],
          physical_disks: data[:physical_disks],
          qemu_cpu_models: data[:qemu_cpu_models],
          qemu_machines: data[:qemu_machines],
          updates_available: data[:updates_available],
          updates: data[:updates],
          offline_note: data[:offline_note]
        )
      end
    end
  end
end
