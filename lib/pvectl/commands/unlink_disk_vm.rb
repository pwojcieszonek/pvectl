# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl unlink disk vm` command.
    #
    # Removes one or more disks from a VM configuration. By default, the
    # disk entry is converted to `unused[n]` (the underlying volume is
    # preserved). With `--force`, the underlying volume is physically
    # deleted.
    #
    # @example Soft unlink (keeps volume as unused0)
    #   pvectl unlink disk vm 100 scsi1
    #
    # @example Unlink multiple disks
    #   pvectl unlink disk vm 100 scsi1,virtio0
    #
    # @example Hard delete the underlying volume
    #   pvectl unlink disk vm 100 scsi1 --force --yes
    #
    class UnlinkDiskVm
      # Registers the unlink command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Unlink a disk from a resource"
        cli.long_desc <<~HELP
          DESCRIPTION
            Remove one or more disks from a VM configuration.

            By default, the disk entry is moved to `unused[n]` in the VM
            config — the underlying volume is preserved so it can be
            re-attached or inspected later. With --force, the underlying
            volume is physically deleted and cannot be recovered.

            Multiple disks may be removed in a single call by passing a
            comma-separated list (e.g. "scsi1,virtio0").

          EXAMPLES
            Soft unlink (keeps the volume as unused0):
              $ pvectl unlink disk vm 100 scsi1

            Unlink multiple disks at once:
              $ pvectl unlink disk vm 100 scsi1,virtio0

            Permanently delete the underlying volume:
              $ pvectl unlink disk vm 100 scsi1 --force --yes

            Skip confirmation prompt:
              $ pvectl unlink disk vm 100 scsi1 -y

          NOTES
            --force is destructive: the underlying volume is removed and
            cannot be recovered. Without --force, the volume can be
            re-attached later (e.g. via `pvectl set vm`).

            The command operates only on QEMU virtual machines; LXC
            containers are not supported by the Proxmox /unlink endpoint.

          SEE ALSO
            pvectl help describe vm     Show VM configuration including disks
            pvectl help edit volume     Edit volume properties interactively
            pvectl help set vm          Modify VM configuration (re-attach unused)
        HELP
        cli.arg_name "RESOURCE_TYPE ID DISK_LIST"
        cli.command :unlink do |c|
          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.desc "Physically delete the underlying volume(s)"
          c.switch [:force], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift
            scope = args.shift

            exit_code = case [resource_type, scope]
            when %w[disk vm]
              Commands::UnlinkDiskVm.execute(args, options, global_options)
            else
              $stderr.puts "Error: Unknown unlink target: #{resource_type} #{scope}".strip
              $stderr.puts "Valid form: unlink disk vm <id> <disk_list>"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the unlink disk vm command.
      #
      # @param args [Array<String>] command arguments (VMID, DISK_LIST)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the unlink disk vm command.
      #
      # @return [Integer] exit code
      def execute
        vmid_arg = @args[0]
        disk_list = @args[1]

        return usage_error("VMID required") if vmid_arg.nil? || vmid_arg.to_s.empty?
        return usage_error("Disk list required (e.g., scsi1 or scsi1,virtio0)") if disk_list.nil? || disk_list.to_s.empty?
        return usage_error("Invalid VMID: #{vmid_arg}") unless vmid_arg.to_s.match?(/\A\d+\z/)

        vmid = vmid_arg.to_i
        load_config
        node = resolve_node(vmid)
        return ExitCodes::NOT_FOUND if node.nil?

        return ExitCodes::SUCCESS unless confirm_operation(vmid, disk_list)

        repo = build_repository
        service = Pvectl::Services::UnlinkDisk.new(repository: repo)
        result = service.execute(
          vmid: vmid,
          node: node,
          disk_ids: disk_list,
          force: @options[:force] == true
        )

        output_result(result)
        result.failed? ? ExitCodes::GENERAL_ERROR : ExitCodes::SUCCESS
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      private

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Resolves the node for a VMID.
      #
      # @param vmid [Integer] VM identifier
      # @return [String, nil] node name or nil if not found
      def resolve_node(vmid)
        connection = Pvectl::Connection.new(@config)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        resolved = resolver.resolve(vmid)

        unless resolved && resolved[:type] == :qemu
          $stderr.puts "Error: VM #{vmid} not found"
          return nil
        end

        resolved[:node]
      end

      # Builds the VM repository.
      #
      # @return [Repositories::Vm] VM repository
      def build_repository
        connection = Pvectl::Connection.new(@config)
        Pvectl::Repositories::Vm.new(connection)
      end

      # Confirms the unlink operation with the user, if not auto-approved.
      #
      # @param vmid [Integer] VM identifier
      # @param disk_list [String] comma-separated disk list
      # @return [Boolean] true to proceed, false to cancel
      def confirm_operation(vmid, disk_list)
        return true if @options[:yes]

        $stdout.puts "About to unlink disk(s) #{disk_list} from VM #{vmid}."
        if @options[:force]
          $stdout.puts ""
          $stdout.puts "WARNING: --force will delete the underlying volume(s) permanently."
          $stdout.puts ""
        end
        $stdout.print "Proceed? [y/N]: "
        $stdout.flush

        answer = $stdin.gets&.strip&.downcase
        answer == "y"
      end

      # Outputs the operation result via the configured formatter.
      #
      # @param result [Models::VmOperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::VmOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        $stdout.puts output
      end

      # Outputs a usage error message and returns the corresponding exit code.
      #
      # @param message [String] error message
      # @return [Integer] usage error exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
