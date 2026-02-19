# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl delete container` command.
    #
    # Deletes one or more LXC containers from the cluster.
    # Always requires confirmation (--yes to skip).
    # Running containers must be stopped first or use --force.
    #
    # @example Delete a single container
    #   pvectl delete container 200 --yes
    #
    # @example Delete using ct alias
    #   pvectl delete ct 200 --yes
    #
    # @example Delete multiple containers
    #   pvectl delete container 200 201 202 --yes
    #
    # @example Force delete running container
    #   pvectl delete container 200 --force --yes
    #
    class DeleteContainer
      include DeleteCommand

      RESOURCE_TYPE = :container
      SUPPORTED_RESOURCES = %w[container ct].freeze
    end
  end
end
