# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Registers the `pvectl resize` command group with subcommands.
      #
      # Currently supports `resize volume`. Designed for extensibility
      # with future subcommands (memory, cpu).
      #
      # @example
      #   Commands::Resize::Command.register(cli)
      #
      class Command
        # Registers the resize command and subcommands with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "Resize a resource property"
          cli.long_desc <<~HELP
            Resize a property of a VM or container. Currently supports volume
            resizing via the 'volume' subcommand.

            SEE ALSO
              pvectl help resize volume   Resize a VM or container volume
          HELP
          cli.command :resize do |c|
            register_volume_subcommand(c)
          end
        end

        # Registers the volume subcommand.
        #
        # @param parent [GLI::Command] parent resize command
        # @return [void]
        def self.register_volume_subcommand(parent)
          parent.desc "Resize a volume on a VM or container"
          parent.arg_name "RESOURCE_TYPE ID VOLUME SIZE"
          parent.long_desc <<~HELP
            Resize a volume on a virtual machine or container. You can specify
            either an absolute size or a relative increase with the + prefix.

            EXAMPLES
              Add 10GB to a VM volume:
                $ pvectl resize volume vm 100 scsi0 +10G

              Add 5GB to a container rootfs:
                $ pvectl resize volume ct 200 rootfs +5G

              Set volume to exactly 50GB (skip confirmation):
                $ pvectl resize volume vm 100 scsi0 50G --yes

              Resize on a specific node:
                $ pvectl resize volume vm 100 scsi0 +10G --node pve1

            NOTES
              Volume resize is irreversible — Proxmox does not support shrinking
              volumes. A confirmation prompt is shown unless --yes is specified.

              Common volume names: scsi0, virtio0, ide0 (VMs), rootfs, mp0 (containers).

              Size format: use G for gigabytes (e.g., +10G, 50G).

            SEE ALSO
              pvectl help describe vm     View current volume configuration
              pvectl help edit            Edit full VM/container configuration
          HELP
          parent.command :volume do |vol_cmd|
            vol_cmd.desc "Skip confirmation prompt"
            vol_cmd.switch [:yes, :y], negatable: false

            vol_cmd.desc "Target node name"
            vol_cmd.flag [:node, :n], arg_name: "NODE"

            vol_cmd.action do |global_options, options, args|
              resource_type = args.shift

              exit_code = case resource_type
              when "vm"
                Resize::ResizeVolumeVm.execute(args, options, global_options)
              when "container", "ct"
                Resize::ResizeVolumeCt.execute(args, options, global_options)
              when nil
                $stderr.puts "Error: Resource type required (vm, container, ct)"
                ExitCodes::USAGE_ERROR
              else
                $stderr.puts "Error: Unknown resource type: #{resource_type}"
                $stderr.puts "Valid types: vm, container, ct"
                ExitCodes::USAGE_ERROR
              end

              exit exit_code if exit_code != 0
            end
          end
        end
        private_class_method :register_volume_subcommand
      end
    end
  end
end
