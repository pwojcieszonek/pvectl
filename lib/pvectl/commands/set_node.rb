# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl set node` command.
    #
    # Includes SetResourceCommand for shared workflow and overrides
    # template methods with node-specific behavior.
    #
    # @example Basic usage
    #   pvectl set node pve1 description="Production node"
    #
    class SetNode
      include SetResourceCommand

      private

      # @return [String] human label for node resources
      def resource_label
        "node"
      end

      # @return [String] human label for node IDs
      def resource_id_label
        "NODE"
      end

      # Builds execution parameters from a node name.
      #
      # @param resource_id [String] node name
      # @param key_values [Hash] parsed key-value pairs
      # @return [Hash] parameters for the set service
      def execute_params(resource_id, key_values)
        { node_name: resource_id, params: key_values }
      end

      # Builds the node set service.
      #
      # @param connection [Connection] API connection
      # @return [Services::SetNode] node set service
      def build_set_service(connection)
        node_repo = Pvectl::Repositories::Node.new(connection)
        Pvectl::Services::SetNode.new(
          node_repository: node_repo,
          options: service_options
        )
      end
    end
  end
end
