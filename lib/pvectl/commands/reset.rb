# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl reset` command.
    #
    # Resets one or more virtual machines (hard reset).
    #
    # @example Reset a single VM
    #   pvectl reset vm 100
    #
    # @example Reset with JSON output
    #   pvectl reset vm 100 -o json
    #
    class Reset
      include VmLifecycleCommand

      # Registers the reset command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Reset virtual machines (hard reset)"
        cli.long_desc <<~HELP
          Hard reset one or more virtual machines. Equivalent to pressing the
          physical reset button — the VM is immediately restarted without
          graceful OS shutdown.

          Only available for VMs. Containers do not support hard reset.

          EXAMPLES
            Hard reset a VM:
              $ pvectl reset vm 100

            Reset multiple VMs:
              $ pvectl reset vm 100 101 102

          NOTES
            May cause data loss or filesystem corruption. Use 'pvectl restart'
            for a graceful reboot instead.

            Not available for containers — use 'pvectl restart ct' instead.

          SEE ALSO
            pvectl help restart         Graceful reboot (VMs and containers)
            pvectl help stop            Hard stop without restart
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :reset do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = execute(resource_type, resource_ids, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :reset
    end
  end
end
