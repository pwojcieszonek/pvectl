# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit container` command.
    #
    # Includes EditResourceCommand for shared workflow and overrides
    # template methods with container-specific behavior.
    #
    # @example Basic usage
    #   pvectl edit container 200
    #
    # @example With custom editor
    #   pvectl edit container 200 --editor nano
    #
    # @example Dry-run mode
    #   pvectl edit container 200 --dry-run
    #
    class EditContainer
      include EditResourceCommand

      private

      # @return [String] human label for container resources
      def resource_label
        "container"
      end

      # @return [String] human label for container IDs
      def resource_id_label
        "CTID"
      end

      # Builds execution parameters from a container ID.
      #
      # @param resource_id [Integer] CTID
      # @return [Hash] parameters for the edit service
      def execute_params(resource_id)
        { ctid: resource_id }
      end

      # Builds the container edit service.
      #
      # @param connection [Connection] API connection
      # @return [Services::EditContainer] container edit service
      def build_edit_service(connection)
        ct_repo = Pvectl::Repositories::Container.new(connection)
        Pvectl::Services::EditContainer.new(
          container_repository: ct_repo,
          editor_session: build_editor_session,
          options: service_options
        )
      end
    end
  end
end
