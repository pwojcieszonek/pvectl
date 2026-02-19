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

      # Registers the migrate command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Migrate a resource to another node"
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :migrate do |c|
          c.desc "Target node (required)"
          c.flag [:target, :t], arg_name: "NODE"

          c.desc "Online/live migration"
          c.switch [:online], negatable: false

          c.desc "Restart migration (container only)"
          c.switch [:restart], negatable: false

          c.desc "Target storage mapping"
          c.flag [:"target-storage"], arg_name: "STORAGE"

          c.desc "Select all resources of this type"
          c.switch [:all, :A], negatable: false

          c.desc "Filter by source node"
          c.flag [:node, :n], arg_name: "NODE"

          c.desc "Filter by selector (e.g., status=running,tags=prod)"
          c.flag [:l, :selector], arg_name: "SELECTOR", multiple: true

          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.desc "Stop on first error"
          c.switch [:"fail-fast"], negatable: false

          c.desc "Wait for migration to complete (sync mode)"
          c.switch [:wait], negatable: false

          c.desc "Timeout in seconds for sync operations (default: 600)"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::MigrateVm.execute(args, options, global_options)
            when "container", "ct"
              Commands::MigrateContainer.execute(args, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, ct"
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
