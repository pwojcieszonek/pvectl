# frozen_string_literal: true

module Pvectl
  module Services
    # Sends a Wake-on-LAN packet to a cluster node.
    #
    # Verifies the node exists in the cluster, calls the WoL API endpoint,
    # and wraps the outcome in a NodeOperationResult. The Proxmox API
    # returns the MAC address used for the magic packet on success, which
    # is surfaced in the result message for confirmation.
    #
    # @example Basic usage
    #   service = Wakeonlan.new(node_repository: repo)
    #   result = service.execute(node_name: "pve3")
    #   result.successful? #=> true
    #   result.message     #=> "Wake-on-LAN packet sent (MAC: AA:BB:CC:DD:EE:FF)"
    #
    # @see Pvectl::Repositories::Node#wakeonlan API call
    # @see Pvectl::Models::NodeOperationResult Returned result wrapper
    #
    class Wakeonlan
      # Creates a new service.
      #
      # @param node_repository [Repositories::Node] Node repository (DI)
      def initialize(node_repository:)
        @node_repository = node_repository
      end

      # Sends the WoL packet to a node.
      #
      # @param node_name [String] target node name
      # @return [Models::NodeOperationResult] outcome (success/failure)
      def execute(node_name:)
        node = @node_repository.get(node_name)
        return not_found_result(node_name) unless node

        mac = @node_repository.wakeonlan(node_name)
        build_result(node, success: true, message: success_message(mac))
      rescue StandardError => e
        build_result(node || Models::Node.new(name: node_name), success: false, error: e.message)
      end

      private

      # Builds a NodeOperationResult.
      #
      # @param node [Models::Node] target node
      # @param attrs [Hash] additional attributes (:success, :error, :message)
      # @return [Models::NodeOperationResult]
      def build_result(node, **attrs)
        Models::NodeOperationResult.new(
          operation: :wakeonlan,
          node_model: node,
          resource: { node_name: node.name },
          **attrs
        )
      end

      # Builds a not-found error result.
      #
      # @param node_name [String]
      # @return [Models::NodeOperationResult]
      def not_found_result(node_name)
        node = Models::Node.new(name: node_name)
        build_result(node, success: false, error: "Node #{node_name} not found")
      end

      # Formats the success message including the MAC address when returned.
      #
      # @param mac [String, nil]
      # @return [String]
      def success_message(mac)
        return "Wake-on-LAN packet sent" if mac.nil? || mac.to_s.empty?

        "Wake-on-LAN packet sent (MAC: #{mac})"
      end
    end
  end
end
