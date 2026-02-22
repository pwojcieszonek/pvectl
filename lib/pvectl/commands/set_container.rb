# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl set container` command.
    #
    # Includes SetResourceCommand for shared workflow and overrides
    # template methods with container-specific behavior.
    #
    # @example Basic usage
    #   pvectl set container 200 memory=2048 hostname=web01
    #
    class SetContainer
      include SetResourceCommand

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
      # @param resource_id [String] CTID
      # @param key_values [Hash] parsed key-value pairs
      # @return [Hash] parameters for the set service
      def execute_params(resource_id, key_values)
        { ctid: resource_id.to_i, params: key_values }
      end

      # Builds the container set service.
      #
      # @param connection [Connection] API connection
      # @return [Services::SetContainer] container set service
      def build_set_service(connection)
        ct_repo = Pvectl::Repositories::Container.new(connection)
        Pvectl::Services::SetContainer.new(
          container_repository: ct_repo,
          options: service_options
        )
      end
    end
  end
end
