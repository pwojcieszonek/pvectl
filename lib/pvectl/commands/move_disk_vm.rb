# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl move disk vm` command.
    #
    # Moves a VM disk to a different storage on the same node.
    # The Proxmox API call is asynchronous — the returned UPID is included
    # in the OperationResult. Use --wait to block until the task completes.
    #
    # @example Move scsi0 of VM 100 to storage2
    #   pvectl move disk vm 100 scsi0 --target storage2
    #
    # @example Move and convert format, deleting source after copy
    #   pvectl move disk vm 100 scsi0 --target storage2 --format qcow2 --delete-source
    #
    class MoveDiskVm
      include MoveDiskCommand

      # Registers the move command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Move a VM disk or container volume to another storage"
        cli.long_desc <<~HELP
          Move a VM disk or container volume to a different storage on the
          same node. The source disk is kept as an unused entry by default;
          pass --delete-source to remove it after a successful copy.

          The operation is asynchronous: the returned task UPID can be
          tracked with `pvectl get tasks` or `pvectl logs task <upid>`.
          Pass --wait to block until the move completes (with --timeout).

          EXAMPLES
            Move VM disk to another storage:
              $ pvectl move disk vm 100 scsi0 --target storage2

            Move VM disk and convert format:
              $ pvectl move disk vm 100 scsi0 --target storage2 --format qcow2

            Move VM disk and delete source after copy:
              $ pvectl move disk vm 100 scsi0 --target storage2 --delete-source

            Move container rootfs to another storage:
              $ pvectl move disk ct 200 rootfs --target storage2

            Move container mount point with bandwidth cap (KiB/s):
              $ pvectl move disk ct 200 mp0 --target storage2 --bandwidth 10240

            Block until completion:
              $ pvectl move disk vm 100 scsi0 --target storage2 --wait

          NOTES
            --target is required and must be a valid storage on the source node.

            --format is only valid for VMs (raw, qcow2, vmdk). It is rejected
            for containers because the LXC API does not accept a format.

            --bandwidth is in KiB/s, matching the Proxmox API directly. The
            operation defaults to the datacenter/storage move limit when omitted.

            For VMs, allowed disk keys include ide0..ide3, scsi0..scsi30,
            virtio0..virtio15, sata0..sata5, efidisk0, tpmstate0, unused*.
            For containers, allowed volume keys include rootfs, mp0..mp255,
            unused*.

          SEE ALSO
            pvectl help migrate         Move a VM/container to another node
            pvectl help clone           Clone a VM or container
            pvectl help get storage     List storages on the cluster
        HELP
        cli.arg_name "SUBJECT RESOURCE_TYPE ID DISK"
        cli.command :move do |c|
          c.desc "Target storage (required)"
          c.flag [:target, :t], arg_name: "STORAGE"

          c.desc "Target disk format (VM only): raw, qcow2, or vmdk"
          c.flag [:format, :f], arg_name: "FORMAT"

          c.desc "Delete source disk after successful copy"
          c.switch [:"delete-source"], negatable: false

          c.desc "Bandwidth limit in KiB/s"
          c.flag [:bandwidth, :b], type: Integer, arg_name: "KIBPS"

          c.desc "Wait for the task to complete (sync mode)"
          c.switch [:wait], negatable: false

          c.desc "Timeout in seconds for sync operations (default: 600)"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.action do |global_options, options, args|
            subject = args.shift
            resource_type = args.shift

            exit_code =
              if subject != "disk"
                $stderr.puts "Error: Unknown subject: #{subject.inspect}"
                $stderr.puts "Valid subjects: disk"
                ExitCodes::USAGE_ERROR
              else
                case resource_type
                when "vm"
                  Commands::MoveDiskVm.execute(args, options, global_options)
                when "container", "ct"
                  Commands::MoveDiskContainer.execute(args, options, global_options)
                else
                  $stderr.puts "Error: Unknown resource type: #{resource_type}"
                  $stderr.puts "Valid types: vm, container, ct"
                  ExitCodes::USAGE_ERROR
                end
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
