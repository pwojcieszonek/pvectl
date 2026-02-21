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
