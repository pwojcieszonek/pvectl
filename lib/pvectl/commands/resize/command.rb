# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Registers the `pvectl resize` command group with subcommands.
      #
      # Currently supports `resize disk`. Designed for extensibility
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
            Resize a property of a VM or container. Currently supports disk
            resizing via the 'disk' subcommand.

            SEE ALSO
              pvectl help resize disk   Resize a VM or container disk
          HELP
          cli.command :resize do |c|
            register_disk_subcommand(c)
          end
        end

        # Registers the disk subcommand.
        #
        # @param parent [GLI::Command] parent resize command
        # @return [void]
        def self.register_disk_subcommand(parent)
          parent.desc "Resize a disk on a VM or container"
          parent.arg_name "RESOURCE_TYPE ID DISK SIZE"
          parent.long_desc <<~HELP
            Resize a disk on a virtual machine or container. You can specify
            either an absolute size or a relative increase with the + prefix.

            EXAMPLES
              Add 10GB to a VM disk:
                $ pvectl resize disk vm 100 scsi0 +10G

              Add 5GB to a container rootfs:
                $ pvectl resize disk ct 200 rootfs +5G

              Set disk to exactly 50GB (skip confirmation):
                $ pvectl resize disk vm 100 scsi0 50G --yes

              Resize on a specific node:
                $ pvectl resize disk vm 100 scsi0 +10G --node pve1

            NOTES
              Disk resize is irreversible — Proxmox does not support shrinking
              disks. A confirmation prompt is shown unless --yes is specified.

              Common disk names: scsi0, virtio0, ide0 (VMs), rootfs, mp0 (containers).

              Size format: use G for gigabytes (e.g., +10G, 50G).

            SEE ALSO
              pvectl help describe vm     View current disk configuration
              pvectl help edit            Edit full VM/container configuration
          HELP
          parent.command :disk do |disk_cmd|
            disk_cmd.desc "Skip confirmation prompt"
            disk_cmd.switch [:yes, :y], negatable: false

            disk_cmd.desc "Target node name"
            disk_cmd.flag [:node, :n], arg_name: "NODE"

            disk_cmd.action do |global_options, options, args|
              resource_type = args.shift

              exit_code = case resource_type
              when "vm"
                Resize::ResizeDiskVm.execute(args, options, global_options)
              when "container", "ct"
                Resize::ResizeDiskCt.execute(args, options, global_options)
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
        private_class_method :register_disk_subcommand
      end
    end
  end
end
