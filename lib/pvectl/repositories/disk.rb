# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for physical disks on Proxmox nodes.
    #
    # Uses the `/nodes/{node}/disks/list` API endpoint to fetch
    # physical disk information per node.
    #
    # @example Listing all disks across the cluster
    #   repo = Disk.new(connection)
    #   disks = repo.list
    #   disks.each { |d| puts "#{d.node}: #{d.devpath} (#{d.type})" }
    #
    # @example Listing disks on a specific node
    #   disks = repo.list(node: "pve1")
    #
    # @see Pvectl::Models::PhysicalDisk PhysicalDisk model
    # @see Pvectl::Connection API connection
    #
    class Disk < Base
      # Lists physical disks, optionally filtered by node.
      #
      # When node is nil, iterates over all online nodes in the cluster.
      # When node is specified, queries only that node.
      #
      # @param node [String, nil] filter by node name
      # @return [Array<Models::PhysicalDisk>] collection of PhysicalDisk models
      def list(node: nil)
        if node
          disks_for_node(node)
        else
          online_nodes.flat_map { |node_name| disks_for_node(node_name) }
        end
      end

      # Fetches SMART data for a specific disk on a node.
      #
      # @param node_name [String] node name
      # @param disk_path [String] device path (e.g., "/dev/nvme0n1")
      # @return [Hash{Symbol => untyped}] SMART data with keys: :health, :type, :attributes, :text
      def smart(node_name, disk_path)
        response = connection.client["nodes/#{node_name}/disks/smart"].get(params: { disk: disk_path })
        extract_data(response)
      rescue StandardError
        {}
      end

      protected

      # Builds PhysicalDisk model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::PhysicalDisk] PhysicalDisk model instance
      def build_model(data)
        Models::PhysicalDisk.new(data)
      end

      private

      # Fetches disks for a single node.
      #
      # @param node_name [String] node name
      # @return [Array<Models::PhysicalDisk>] disks on that node
      def disks_for_node(node_name)
        response = connection.client["nodes/#{node_name}/disks/list"].get
        disks_data = unwrap(response)
        disks_data.map { |data| build_model(data.merge(node: node_name)) }
      rescue StandardError
        []
      end

      # Fetches list of online node names.
      #
      # @return [Array<String>] online node names
      def online_nodes
        response = connection.client["nodes"].get
        nodes_data = unwrap(response)
        nodes_data
          .select { |n| n[:status] == "online" }
          .map { |n| n[:node] || n[:name] }
      rescue StandardError
        []
      end
    end
  end
end
