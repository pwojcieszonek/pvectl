# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit vm` command.
    #
    # Includes EditResourceCommand for shared workflow and overrides
    # template methods with VM-specific behavior.
    #
    # @example Basic usage
    #   pvectl edit vm 100
    #
    # @example With custom editor
    #   pvectl edit vm 100 --editor nano
    #
    # @example Dry-run mode
    #   pvectl edit vm 100 --dry-run
    #
    class EditVm
      include EditResourceCommand

      # Registers the edit command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Edit a resource configuration"
        cli.long_desc "Opens the current configuration of a VM or container in your $EDITOR as YAML. " \
                      "After editing, validates changes and applies them to the Proxmox API."
        cli.arg_name "RESOURCE_TYPE RESOURCE_ID"
        cli.command :edit do |c|
          c.desc "Override editor command (default: $EDITOR or vi)"
          c.flag [:editor], arg_name: "CMD"

          c.desc "Show diff without applying changes"
          c.switch [:"dry-run"], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args

            exit_code = case resource_type
            when "vm"
              Commands::EditVm.execute(resource_ids, options, global_options)
            when "container", "ct"
              Commands::EditContainer.execute(resource_ids, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      private

      # @return [String] human label for VM resources
      def resource_label
        "VM"
      end

      # @return [String] human label for VM IDs
      def resource_id_label
        "VMID"
      end

      # Builds execution parameters from a VM ID.
      #
      # @param resource_id [Integer] VMID
      # @return [Hash] parameters for the edit service
      def execute_params(resource_id)
        { vmid: resource_id }
      end

      # Builds the VM edit service.
      #
      # @param connection [Connection] API connection
      # @return [Services::EditVm] VM edit service
      def build_edit_service(connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        Pvectl::Services::EditVm.new(
          vm_repository: vm_repo,
          editor_session: build_editor_session,
          options: service_options
        )
      end
    end
  end
end
