# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl restart` command.
    #
    # Restarts one or more virtual machines (reboot).
    #
    # @example Restart a single VM
    #   pvectl restart vm 100
    #
    # @example Restart with sync mode
    #   pvectl restart vm 100 --wait
    #
    class Restart
      include VmLifecycleCommand

      # Registers the restart command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Restart virtual machines or containers (reboot)"
        cli.long_desc <<~HELP
          Reboot one or more virtual machines or containers. Sends a reboot
          signal to the guest OS for a clean restart.

          EXAMPLES
            Reboot a VM:
              $ pvectl restart vm 100

            Reboot a container:
              $ pvectl restart ct 200

            Reboot all VMs with a specific tag:
              $ pvectl restart vm --all -l tags=webserver --yes

          NOTES
            For VMs, this sends an ACPI reboot signal (requires guest agent or
            ACPI support). For containers, uses LXC reboot.

            For a hard reset (equivalent to pressing the reset button), use
            'pvectl reset' instead (VMs only).

          SEE ALSO
            pvectl help reset           Hard reset (VMs only)
            pvectl help shutdown        Graceful shutdown without restart
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :restart do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = case resource_type
            when "container", "ct"
              RestartContainer.execute(resource_type, resource_ids, options, global_options)
            else
              execute(resource_type, resource_ids, options, global_options)
            end
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :restart
    end
  end
end
