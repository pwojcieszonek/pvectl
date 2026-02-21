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

      # Registers the delete command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Delete a resource"
        cli.long_desc <<~HELP
          Delete virtual machines, containers, snapshots, or backups.

          Destructive operations require confirmation (--yes flag or interactive
          prompt). Use --force to stop running resources before deletion.

          SUBCOMMANDS
            delete vm ID...              Delete virtual machines
            delete container ID...       Delete LXC containers
            delete snapshot NAME         Delete snapshots (see: pvectl help delete snapshot)
            delete backup VOLID...       Delete backup volumes

          EXAMPLES
            Delete a stopped VM:
              $ pvectl delete vm 100 --yes

            Force-delete a running VM (stops it first):
              $ pvectl delete vm 100 --force --yes

            Delete VM but keep its disks:
              $ pvectl delete vm 100 --keep-disks --yes

            Delete a backup by volume ID:
              $ pvectl delete backup local:backup/vzdump-qemu-100-2026_01_01.vma.zst --yes

          NOTES
            Deletion is irreversible. Always verify the resource ID before confirming.

            --force stops a running VM/container before deleting.
            --purge removes the resource from replication and backup jobs.

          SEE ALSO
            pvectl help get             List resources to find IDs
            pvectl help create          Create new resources
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...] [NAME]"
        cli.command :delete do |c|
          c.desc "Skip confirmation prompt (REQUIRED for destructive operations)"
          c.switch [:yes, :y], negatable: false

          c.desc "Force stop running VM/container before deletion"
          c.switch [:force, :f], negatable: false

          c.desc "Keep disks (do not destroy)"
          c.switch [:"keep-disks"], negatable: false

          c.desc "Remove from HA, replication, and backups"
          c.switch [:purge], negatable: false

          c.desc "Select all resources of this type"
          c.switch [:all, :A], negatable: false

          c.desc "Filter by node name"
          c.flag [:node, :n], arg_name: "NODE"

          c.desc "Filter by selector (e.g., status=running,tags=prod)"
          c.flag [:l, :selector], arg_name: "SELECTOR", multiple: true

          c.desc "Timeout in seconds for sync operations"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Force async mode (return task ID immediately)"
          c.switch [:async], negatable: false

          c.desc "Stop on first error (default: continue and report all)"
          c.switch [:"fail-fast"], negatable: false

          # Sub-commands
          DeleteSnapshot.register_subcommand(c)

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::DeleteVm.execute(resource_type, args, options, global_options)
            when "container", "ct"
              Commands::DeleteContainer.execute(resource_type, args, options, global_options)
            when "backup"
              Commands::DeleteBackup.execute(resource_type, args, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, backup (or use: delete snapshot)"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      RESOURCE_TYPE = :vm
      SUPPORTED_RESOURCES = %w[vm].freeze
    end
  end
end
