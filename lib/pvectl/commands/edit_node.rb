# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit node` command.
    #
    # Includes EditResourceCommand for shared workflow and overrides
    # template methods with node-specific behavior.
    #
    # @example Basic usage
    #   pvectl edit node pve1
    #
    # @example Dry-run mode
    #   pvectl edit node pve1 --dry-run
    #
    class EditNode
      include EditResourceCommand

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
      # Node uses string name (not integer ID).
      #
      # @param resource_id [String] node name
      # @return [Hash] parameters for the edit service
      def execute_params(resource_id)
        { node_name: resource_id }
      end

      # Builds the node edit service.
      #
      # @param connection [Connection] API connection
      # @return [Services::EditNode] node edit service
      def build_edit_service(connection)
        node_repo = Pvectl::Repositories::Node.new(connection)
        Pvectl::Services::EditNode.new(
          node_repository: node_repo,
          editor_session: build_editor_session,
          options: service_options
        )
      end
    end
  end
end
