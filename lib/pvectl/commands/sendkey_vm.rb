# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl sendkey vm` command.
    #
    # Sends a single QEMU monitor key event to a running VM. The key string
    # uses QEMU's qcode format (e.g., +ctrl-alt-delete+, +ret+, +f1+) and is
    # forwarded verbatim to the Proxmox API.
    #
    # @example Send Ctrl+Alt+Delete to VM 100
    #   pvectl sendkey vm 100 ctrl-alt-delete
    #
    # @example Send Enter to VM 100
    #   pvectl sendkey vm 100 ret
    #
    class SendkeyVm
      # Registers the sendkey command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Send a QEMU monitor key event to a VM"
        cli.long_desc <<~HELP
          Send a single QEMU monitor key event to a running virtual machine.
          The key string is forwarded verbatim to the Proxmox API and is
          interpreted by QEMU using its qcode key format.

          Common key codes:
            - ctrl-alt-delete    Reboot signal (Linux/Windows)
            - ctrl-alt-f1..f6    Switch Linux virtual terminals
            - ret                Enter / Return
            - esc                Escape
            - tab, spc, backspace

          Single character keys (letters, digits) are also accepted as-is.

          EXAMPLES
            Trigger Ctrl+Alt+Del on a running VM:
              $ pvectl sendkey vm 100 ctrl-alt-delete

            Send Enter (e.g., dismiss a bootloader prompt):
              $ pvectl sendkey vm 100 ret

            Send Escape:
              $ pvectl sendkey vm 100 esc

            Switch to TTY 1 on a Linux guest:
              $ pvectl sendkey vm 100 ctrl-alt-f1

            Resolve VM on a specific node:
              $ pvectl sendkey vm 100 ret --node pve1

          NOTES
            Only VMs are supported — LXC containers do not have a QEMU monitor.

            The VM must be running. If it is not, the command exits with an
            error before issuing the API call.

            Composite keys are dash-separated qcodes (e.g., "ctrl-alt-f1"),
            not the literal "+" notation. Refer to QEMU's qcode reference
            for the full list.

          SEE ALSO
            pvectl help console vm      Interactive console (recommended for
                                        sustained typing)
            pvectl help start           Start a stopped VM
        HELP
        cli.arg_name "RESOURCE_TYPE ID KEY"
        cli.command :sendkey do |c|
          c.desc "Node hosting the VM (used to disambiguate lookup)"
          c.flag [:node, :n], arg_name: "NODE"

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              SendkeyVm.execute(args, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the sendkey VM command.
      #
      # @param args [Array<String>] command arguments (VMID KEY)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a sendkey VM command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args)
        @options = options || {}
        @global_options = global_options || {}
      end

      # Executes the sendkey VM command.
      #
      # @return [Integer] exit code
      def execute
        vmid_arg = @args[0]
        key = @args[1]

        return usage_error("VMID is required") if vmid_arg.nil? || vmid_arg.to_s.strip.empty?
        return usage_error("VMID must be numeric: #{vmid_arg}") unless vmid_arg.to_s.match?(/\A\d+\z/)
        return usage_error("key argument is required") if key.nil? || key.to_s.strip.empty?

        perform_sendkey(vmid_arg.to_i, key)
      end

      private

      # Loads the config, builds the service, and dispatches the call.
      #
      # @param vmid [Integer] VM identifier
      # @param key [String] key sequence
      # @return [Integer] exit code
      def perform_sendkey(vmid, key)
        load_config
        connection = Pvectl::Connection.new(@config)
        vm_repo = Pvectl::Repositories::Vm.new(connection)

        service = Pvectl::Services::Sendkey.new(vm_repository: vm_repo)
        result = service.execute(vmid: vmid, key: key, node: @options[:node])

        output_result(result)

        return ExitCodes::NOT_FOUND if vm_not_found?(result)

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

      # Detects the "VM not found" failure case.
      #
      # @param result [Models::VmOperationResult]
      # @return [Boolean]
      def vm_not_found?(result)
        result.failed? && result.vm.nil? && result.error.to_s.include?("not found")
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Outputs the operation result using the configured formatter.
      #
      # @param result [Models::VmOperationResult]
      # @return [void]
      def output_result(result)
        # When the VM could not be resolved we have no VM info — write a
        # plain stderr error instead of a presenter row referencing nil.
        if result.failed? && result.vm.nil?
          $stderr.puts "Error: #{result.error}"
          return
        end

        presenter = Pvectl::Presenters::VmOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
      end

      # Writes a usage error and returns the exit code.
      #
      # @param message [String]
      # @return [Integer]
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
