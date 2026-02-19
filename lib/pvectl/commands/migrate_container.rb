# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl migrate container` command.
    #
    # Migrates one or more LXC containers to another cluster node.
    # Always requires --target and confirmation (--yes to skip).
    #
    # @example Migrate a single container
    #   pvectl migrate container 200 --target pve2 --yes
    #
    # @example Restart migration
    #   pvectl migrate container 200 --target pve2 --restart --yes
    #
    class MigrateContainer
      include MigrateCommand

      RESOURCE_TYPE = :container
      SUPPORTED_RESOURCES = %w[container ct].freeze
    end
  end
end
