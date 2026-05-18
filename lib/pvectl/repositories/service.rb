# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for systemd services on Proxmox nodes.
    #
    # Wraps the `/nodes/{node}/services` API endpoints. Provides listing of
    # services on a node and lifecycle operations (start/stop/restart/reload)
    # which return Proxmox task UPIDs.
    #
    # @example Listing services on a node
    #   repo = Service.new(connection)
    #   services = repo.list(node: "pve1")
    #   services.each { |s| puts "#{s.service}: #{s.active_state}" }
    #
    # @example Restarting a service
    #   upid = repo.restart("pve1", "pveproxy")
    #
    # @see Pvectl::Models::Service Service model
    # @see Pvectl::Connection API connection
    #
    class Service < Base
      # Lists systemd services on a node.
      #
      # When node is nil, iterates over all online nodes in the cluster.
      # When node is specified, queries only that node.
      #
      # @param node [String, nil] node name (or nil for all online nodes)
      # @return [Array<Models::Service>] collection of Service models
      def list(node: nil)
        if node
          services_for_node(node)
        else
          online_nodes.flat_map { |node_name| services_for_node(node_name) }
        end
      end

      # Reads single service state.
      #
      # @param node [String] node name
      # @param service [String] service identifier (e.g., "pveproxy")
      # @return [Models::Service, nil] service model or nil on error
      def state(node, service)
        resp = connection.client["nodes/#{node}/services/#{service}/state"].get
        data = extract_data(resp)
        return nil if data.nil? || data.empty?

        build_model(data.merge(node: node))
      rescue StandardError
        nil
      end

      # Starts a service. Returns the task UPID.
      #
      # @param node [String] node name
      # @param service [String] service identifier
      # @return [String] task UPID
      def start(node, service)
        post_action(node, service, "start")
      end

      # Stops a service. Returns the task UPID.
      #
      # @param node [String] node name
      # @param service [String] service identifier
      # @return [String] task UPID
      def stop(node, service)
        post_action(node, service, "stop")
      end

      # Hard-restarts a service. Returns the task UPID.
      #
      # @param node [String] node name
      # @param service [String] service identifier
      # @return [String] task UPID
      def restart(node, service)
        post_action(node, service, "restart")
      end

      # Reloads a service (falls back to restart if unsupported). Returns the task UPID.
      #
      # @param node [String] node name
      # @param service [String] service identifier
      # @return [String] task UPID
      def reload(node, service)
        post_action(node, service, "reload")
      end

      protected

      # Builds Service model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::Service] Service model instance
      def build_model(data)
        Models::Service.new(data)
      end

      private

      # POSTs a lifecycle action and extracts the UPID from the response.
      #
      # @param node [String] node name
      # @param service [String] service identifier
      # @param action [String] one of "start", "stop", "restart", "reload"
      # @return [String] task UPID
      def post_action(node, service, action)
        resp = connection.client["nodes/#{node}/services/#{service}/#{action}"].post({})
        data = extract_data(resp)
        data.is_a?(String) ? data : data.to_s
      end

      # Fetches services for a single node.
      #
      # @param node_name [String] node name
      # @return [Array<Models::Service>] services on that node
      def services_for_node(node_name)
        response = connection.client["nodes/#{node_name}/services"].get
        services_data = unwrap(response)
        services_data.map { |data| build_model(data.merge(node: node_name)) }
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
