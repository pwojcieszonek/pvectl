# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox subscription information per node.
    #
    # Wraps the `GET /nodes/{node}/subscription` endpoint and aggregates
    # subscription records across all nodes in the cluster.
    #
    # @example Listing subscriptions across the cluster
    #   repo = Subscription.new(connection)
    #   repo.list.each { |s| puts "#{s.node}: #{s.status} #{s.level}" }
    #
    # @see Pvectl::Models::Subscription
    #
    class Subscription < Base
      # Lists subscription records for cluster nodes.
      #
      # Returns one Subscription per online node. Offline / unreachable
      # nodes return a Subscription with status="unreachable" so the output
      # remains stable instead of silently dropping rows.
      #
      # @param node [String, nil] filter to a single node (otherwise all online nodes)
      # @return [Array<Models::Subscription>]
      def list(node: nil)
        node_names = node ? [node] : online_node_names
        node_names.map { |name| fetch_for(name) }
      end

      # Fetches the subscription record for a single node.
      #
      # @param node [String] node name
      # @return [Models::Subscription]
      def get(node)
        fetch_for(node)
      end

      protected

      # Builds a Subscription model from API data plus the node name.
      #
      # @param data [Hash] API response payload (already extracted from :data wrapper)
      # @param node_name [String] node the record belongs to
      # @return [Models::Subscription]
      def build_model(data, node_name)
        attrs = (data || {}).merge(node: node_name)
        Models::Subscription.new(attrs)
      end

      private

      # Returns names of all online nodes in the cluster.
      #
      # @return [Array<String>]
      def online_node_names
        response = connection.client["nodes"].get
        nodes = unwrap(response)
        nodes
          .select { |n| n[:status].nil? || n[:status] == "online" }
          .map { |n| n[:node] || n[:name] }
          .compact
      end

      # Fetches one node's subscription, recovering from API errors gracefully.
      #
      # @param node_name [String]
      # @return [Models::Subscription]
      def fetch_for(node_name)
        response = connection.client["nodes/#{node_name}/subscription"].get
        data = extract_data(response)
        build_model(data, node_name)
      rescue StandardError => e
        build_model({ status: "unreachable", message: e.message }, node_name)
      end
    end
  end
end
