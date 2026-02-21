# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl shutdown` command.
    #
    # Shuts down one or more virtual machines gracefully (ACPI).
    #
    # @example Shutdown a single VM
    #   pvectl shutdown vm 100
    #
    # @example Shutdown with sync mode
    #   pvectl shutdown vm 100 --wait
    #
    class Shutdown
      include VmLifecycleCommand

      # Registers the shutdown command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Shutdown virtual machines or containers gracefully"
        cli.long_desc <<~HELP
          Gracefully shut down one or more virtual machines or containers.
          Sends an ACPI shutdown signal to VMs or a clean shutdown to containers,
          allowing the guest OS to shut down properly.

          This is the recommended way to stop production workloads. For
          immediate termination, use 'pvectl stop' instead.

          EXAMPLES
            Graceful shutdown of a VM:
              $ pvectl shutdown vm 100

            Shutdown with wait and timeout:
              $ pvectl shutdown vm 100 --wait --timeout 120

            Shutdown all running VMs on a node:
              $ pvectl shutdown vm --all --node pve1 -l status=running --yes

          NOTES
            Requires QEMU Guest Agent or ACPI support in the VM for graceful
            shutdown. If the guest doesn't respond, the shutdown may time out.

            Use --timeout with --wait to set a maximum wait time.

          SEE ALSO
            pvectl help stop            Hard stop (immediate, may cause data loss)
            pvectl help restart         Reboot resources
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :shutdown do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = case resource_type
            when "container", "ct"
              ShutdownContainer.execute(resource_type, resource_ids, options, global_options)
            else
              execute(resource_type, resource_ids, options, global_options)
            end
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :shutdown
    end
  end
end
