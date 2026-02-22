# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl set vm` command.
    #
    # Includes SetResourceCommand for shared workflow and overrides
    # template methods with VM-specific behavior.
    #
    # Also registers the top-level `set` command with all resource types.
    #
    # @example Basic usage
    #   pvectl set vm 100 memory=4096 cores=2
    #
    # @example Dry-run mode
    #   pvectl set vm 100 memory=8192 --dry-run
    #
    class SetVm
      include SetResourceCommand

      # Registers the set command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Set a resource property (non-interactive)"
        cli.long_desc <<~HELP
          Set configuration properties on a resource without opening an editor.
          Accepts key=value pairs as arguments. This is the non-interactive
          counterpart to the edit command.

          EXAMPLES
            Set VM memory and CPU:
              $ pvectl set vm 100 memory=4096 cores=2

            Set container hostname:
              $ pvectl set container 200 hostname=web01

            Resize a volume:
              $ pvectl set volume vm 100 scsi0 size=+10G

            Set volume cache mode:
              $ pvectl set volume vm 100 scsi0 cache=writeback

            Set node description:
              $ pvectl set node pve1 description="Production node"

            Preview changes without applying:
              $ pvectl set vm 100 memory=8192 --dry-run

          NOTES
            Volume resize (size=) is irreversible. A confirmation prompt is shown
            unless --yes is specified.

            Keys are passed directly to the Proxmox API. Use Proxmox documentation
            to find valid configuration keys for each resource type.

          SEE ALSO
            pvectl help edit        Interactive configuration editor
            pvectl help describe    View current configuration
        HELP
        cli.arg_name "RESOURCE_TYPE RESOURCE_ID [SUB_ID] KEY=VALUE [KEY=VALUE ...]"
        cli.command :set do |c|
          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.desc "Target node name"
          c.flag [:node, :n], arg_name: "NODE"

          c.desc "Show diff without applying changes"
          c.switch [:"dry-run"], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::SetVm.execute(args, options, global_options)
            when "container", "ct"
              Commands::SetContainer.execute(args, options, global_options)
            when "volume", "vol"
              Commands::SetVolume.execute(args, options, global_options)
            when "node"
              Commands::SetNode.execute(args, options, global_options)
            when nil
              $stderr.puts "Error: Resource type required (vm, container, volume, node)"
              ExitCodes::USAGE_ERROR
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, volume, node"
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
      # @param resource_id [String] VMID
      # @param key_values [Hash] parsed key-value pairs
      # @return [Hash] parameters for the set service
      def execute_params(resource_id, key_values)
        { vmid: resource_id.to_i, params: key_values }
      end

      # Builds the VM set service.
      #
      # @param connection [Connection] API connection
      # @return [Services::SetVm] VM set service
      def build_set_service(connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        Pvectl::Services::SetVm.new(
          vm_repository: vm_repo,
          options: service_options
        )
      end
    end
  end
end
