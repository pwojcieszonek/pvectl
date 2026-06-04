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
        cli.long_desc <<~HELP
          Open a VM, container, node, or volume configuration in your text
          editor. The configuration is presented as YAML for easy editing.
          Changes are applied via the Proxmox API when you save and close
          the editor.

          EXAMPLES
            Edit a VM configuration:
              $ pvectl edit vm 100

            Edit a container with a specific editor:
              $ pvectl edit container 200 --editor nano

            Edit a node configuration:
              $ pvectl edit node pve1

            Edit node DNS resolver settings:
              $ pvectl edit dns pve1

            Edit volume properties:
              $ pvectl edit volume vm 100 scsi0

            Edit /etc/hosts on a node:
              $ pvectl edit hosts pve1

            Preview changes without applying:
              $ pvectl edit vm 100 --dry-run

          NOTES
            Uses $EDITOR environment variable by default, falling back to vi.
            Override with --editor flag.

            In --dry-run mode, shows the diff between current and edited
            configuration without applying changes to Proxmox.

            Supported resource types: vm, container (ct), node, volume, dns, hosts.

            For DNS, the node identifier is given as a positional argument
            (pvectl edit dns NODE). DNS settings include search domain and
            up to three nameservers (dns1, dns2, dns3).

            For volumes, syntax is: pvectl edit volume <vm|container> <id> <disk>

            For hosts, the node identifier is given as a positional argument
            (pvectl edit hosts NODE). The /etc/hosts file is edited as raw
            text — Proxmox requires the pvelocalhost entry to remain present
            and will reject updates removing it.

            Not all configuration keys can be changed while a VM is running.
            Proxmox will reject invalid changes with an error message.

          SEE ALSO
            pvectl help describe        View current configuration (read-only)
            pvectl help create          Create a new resource
            pvectl help set             Set individual resource properties
        HELP
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
            when "node"
              Commands::EditNode.execute(resource_ids, options, global_options)
            when "volume"
              Commands::EditVolume.execute(resource_ids, options, global_options)
            when "dns"
              Commands::EditDns.execute(resource_ids, options, global_options)
            when "hosts"
              Commands::EditHosts.execute(resource_ids, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, node, volume, dns, hosts"
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
      # @param resource_id [String] VMID (converted to Integer)
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
          name_resolver: Pvectl::Utils::ResourceResolver.new(connection),
          options: service_options
        )
      end
    end
  end
end
