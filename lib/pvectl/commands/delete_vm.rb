# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl delete vm` command.
    #
    # Deletes one or more virtual machines from the cluster.
    # Always requires confirmation (--yes to skip).
    # Running VMs must be stopped first or use --force.
    #
    # @example Delete a single VM
    #   pvectl delete vm 100 --yes
    #
    # @example Delete multiple VMs
    #   pvectl delete vm 100 101 102 --yes
    #
    # @example Force delete running VM
    #   pvectl delete vm 100 --force --yes
    #
    # @example Keep disks after deletion
    #   pvectl delete vm 100 --keep-disks --yes
    #
    class DeleteVm
      include DeleteCommand

      RESOURCE_TYPE = :vm
      SUPPORTED_RESOURCES = %w[vm].freeze
    end
  end
end
