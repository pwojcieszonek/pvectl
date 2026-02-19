# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl migrate vm` command.
    #
    # Migrates one or more virtual machines to another cluster node.
    # Always requires --target and confirmation (--yes to skip).
    #
    # @example Migrate a single VM
    #   pvectl migrate vm 100 --target pve2 --yes
    #
    # @example Online migration
    #   pvectl migrate vm 100 --target pve2 --online --yes
    #
    class MigrateVm
      include MigrateCommand

      RESOURCE_TYPE = :vm
      SUPPORTED_RESOURCES = %w[vm].freeze
    end
  end
end
