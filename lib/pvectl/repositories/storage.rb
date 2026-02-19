# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox cluster storage pools.
    #
    # Uses the `/cluster/resources?type=storage` API endpoint for cluster-wide view.
    # Handles aggregation of shared storage (deduplication by name).
    #
    # @example Listing all storage pools
    #   repo = Storage.new(connection)
    #   storage_pools = repo.list
    #   storage_pools.each { |s| puts "#{s.name}: #{s.plugintype}" }
    #
    # @example Listing storage on a specific node
    #   storage_pools = repo.list(node: "pve1")
    #
    # @see Pvectl::Models::Storage Storage model
    # @see Pvectl::Connection API connection
    #
    class Storage < Base
      # Lists all storage pools in the cluster.
      #
      # Uses `/cluster/resources?type=storage` endpoint for cluster-wide view.
      # Aggregates shared storage by keeping first entry per storage name.
      #
      # @param node [String, nil] filter by node name
      # @return [Array<Models::Storage>] collection of Storage models
      def list(node: nil)
        response = connection.client["cluster/resources"].get(params: { type: "storage" })
        storage_data = normalize_response(response)

        # Aggregate shared storage (deduplicate by name, keep first entry)
        aggregated = aggregate_storage(storage_data)

        # Filter by node if specified
        if node
          aggregated = aggregated.select { |data| data[:node] == node || data[:shared] == 1 }
        end

        aggregated.map { |data| build_model(data) }
      end

      # Gets a single storage pool by name.
      #
      # @param name [String] storage pool name
      # @return [Models::Storage, nil] Storage model or nil if not found
      def get(name)
        list.find { |s| s.name == name }
      end

      # Lists all instances of a storage by name.
      #
      # For shared storage: returns single instance.
      # For local storage: returns all instances (one per node).
      #
      # @param name [String] storage name
      # @return [Array<Models::Storage>] array of storage instances
      def list_instances(name)
        response = connection.client["cluster/resources"].get(params: { type: "storage" })
        storage_data = normalize_response(response)
        storage_data.select { |s| s[:storage] == name }.map { |data| build_model(data) }
      end

      # Gets storage for a specific node.
      #
      # @param name [String] storage name
      # @param node [String] node name
      # @return [Models::Storage, nil] Storage model or nil if not found
      def get_for_node(name, node)
        list_instances(name).find { |s| s.node == node }
      end

      # Describes a storage with comprehensive details from multiple API endpoints.
      #
      # Fetches:
      # - Basic storage info from cluster resources (via get or get_for_node)
      # - Configuration from /storage/{name}
      # - Status from /nodes/{node}/storage/{name}/status
      # - Content (volumes) from /nodes/{node}/storage/{name}/content
      #
      # @param name [String] storage name
      # @param node [String, nil] specific node for local storage
      # @return [Models::Storage, nil] Storage model with full details, or nil if not found
      def describe(name, node: nil)
        storage = node ? get_for_node(name, node) : get(name)
        return nil unless storage

        # GET /storage/{name} - configuration
        config = fetch_storage_config(name)

        # Find active node for this storage
        node = find_node_for_storage(name, storage)

        # GET /nodes/{node}/storage/{name}/status (if node available)
        status = node ? fetch_storage_status(node, name) : {}

        # GET /nodes/{node}/storage/{name}/content (volumes)
        content = node ? fetch_storage_content(node, name) : []

        build_describe_model(storage, config, status, content)
      end

      # Lists storage pools for a specific node.
      #
      # Uses `/nodes/{node}/storage` endpoint which returns detailed
      # per-node storage information including avail, enabled, active flags.
      #
      # @param node_name [String] node name
      # @return [Array<Models::Storage>] collection of Storage models
      def list_for_node(node_name)
        response = connection.client["nodes/#{node_name}/storage"].get
        storage_data = normalize_response(response)

        storage_data.map { |data| build_model_from_node_api(data, node_name) }
      end

      protected

      # Builds Storage model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::Storage] Storage model instance
      def build_model(data)
        Models::Storage.new(
          name: data[:storage],
          plugintype: data[:plugintype],
          status: data[:status],
          node: data[:node],
          disk: data[:disk],
          maxdisk: data[:maxdisk],
          content: data[:content],
          shared: data[:shared]
        )
      end

      # Builds Storage model from /nodes/{node}/storage API response.
      #
      # Maps node-specific API fields to model attributes:
      # - type -> plugintype
      # - used -> disk
      # - total -> maxdisk
      # - active -> status (derived)
      #
      # @param data [Hash] API response hash
      # @param node_name [String] node name (not in response, passed as param)
      # @return [Models::Storage] Storage model instance
      def build_model_from_node_api(data, node_name)
        Models::Storage.new(
          name: data[:storage],
          plugintype: data[:type],
          node: node_name,
          disk: data[:used],
          maxdisk: data[:total],
          avail: data[:avail],
          content: data[:content],
          enabled: data[:enabled],
          active: data[:active],
          shared: 0 # /nodes/{node}/storage doesn't return shared flag
        )
      end

      private

      # Fetches storage configuration from /storage/{name}.
      #
      # @param name [String] storage name
      # @return [Hash] configuration data or empty hash on error
      def fetch_storage_config(name)
        response = connection.client["storage/#{name}"].get
        extract_data(response)
      rescue StandardError
        {}
      end

      # Fetches storage status from /nodes/{node}/storage/{name}/status.
      #
      # @param node [String] node name
      # @param name [String] storage name
      # @return [Hash] status data or empty hash on error
      def fetch_storage_status(node, name)
        response = connection.client["nodes/#{node}/storage/#{name}/status"].get
        extract_data(response)
      rescue StandardError
        {}
      end

      # Fetches storage content (volumes) from /nodes/{node}/storage/{name}/content.
      #
      # @param node [String] node name
      # @param name [String] storage name
      # @return [Array<Hash>] volumes array or empty array on error
      def fetch_storage_content(node, name)
        response = connection.client["nodes/#{node}/storage/#{name}/content"].get
        unwrap(response)
      rescue StandardError
        []
      end

      # Finds an active node where this storage is accessible.
      #
      # For local storage: uses the node it belongs to.
      # For shared storage: finds first online node in the cluster.
      #
      # @param name [String] storage name
      # @param storage [Models::Storage] storage model
      # @return [String, nil] node name or nil if unavailable
      def find_node_for_storage(name, storage)
        # For local storage, use the node it belongs to
        return storage.node unless storage.shared?

        # For shared storage, find first available online node
        nodes_response = connection.client["nodes"].get
        nodes = unwrap(nodes_response)
        online_node = nodes.find { |n| n[:status] == "online" }
        online_node&.dig(:node)
      rescue StandardError
        nil
      end

      # Builds Storage model with comprehensive describe data.
      #
      # Merges data from basic storage, config, status, and content endpoints.
      #
      # @param storage [Models::Storage] base storage model
      # @param config [Hash] configuration from /storage/{name}
      # @param status [Hash] status from /nodes/{node}/storage/{name}/status
      # @param content [Array<Hash>] volumes from /content endpoint
      # @return [Models::Storage] complete storage model
      def build_describe_model(storage, config, status, content)
        Models::Storage.new(
          # Basic attributes from list
          name: storage.name,
          plugintype: storage.plugintype,
          status: storage.status,
          node: storage.node,
          disk: storage.disk,
          maxdisk: storage.maxdisk,
          content: storage.content,
          shared: storage.shared,

          # Config attributes
          path: config[:path],
          server: config[:server],
          export: config[:export],
          pool: config[:pool],
          vgname: config[:vgname],
          thinpool: config[:thinpool],
          nodes: config[:nodes],
          "prune-backups": config[:"prune-backups"],
          maxfiles: config[:maxfiles],

          # Status attributes (override if available)
          avail: status[:avail] || storage.avail,
          enabled: status[:enabled] || storage.enabled,
          active: status[:active] || storage.active_flag,

          # Content (volumes)
          volumes: content
        )
      end

      # Normalizes API response to array format.
      #
      # @param response [Array, Hash] API response
      # @return [Array<Hash>] array of storage data hashes
      def normalize_response(response)
        if response.is_a?(Array)
          response
        elsif response.is_a?(Hash) && response[:data]
          response[:data]
        else
          response.to_a
        end
      end

      # Aggregates storage data by name.
      # For shared storage, keeps first entry (data is identical across nodes).
      # For local storage, keeps all entries.
      #
      # @param storage_data [Array<Hash>] raw storage data from API
      # @return [Array<Hash>] aggregated storage data
      def aggregate_storage(storage_data)
        seen = {}
        storage_data.each do |data|
          name = data[:storage]
          next if name.nil?

          # For shared storage, keep only first entry
          if data[:shared] == 1
            seen[name] ||= data
          else
            # For local storage, include all (unique by name+node)
            key = "#{name}:#{data[:node]}"
            seen[key] ||= data
          end
        end
        seen.values
      end
    end
  end
end
