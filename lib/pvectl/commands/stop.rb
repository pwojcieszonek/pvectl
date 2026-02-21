# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl stop` command.
    #
    # Stops one or more virtual machines (hard stop).
    #
    # @example Stop a single VM
    #   pvectl stop vm 100
    #
    # @example Stop with JSON output
    #   pvectl stop vm 100 -o json
    #
    class Stop
      include VmLifecycleCommand

      # Registers the stop command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Stop virtual machines or containers (hard stop)"
        cli.long_desc <<~HELP
          Immediately stop one or more virtual machines or containers. This is
          a hard stop (equivalent to pulling the power cord) — the guest OS is
          NOT shut down gracefully.

          For a clean shutdown, use 'pvectl shutdown' instead.

          EXAMPLES
            Hard stop a VM:
              $ pvectl stop vm 100

            Stop multiple containers:
              $ pvectl stop ct 200 201

            Stop all running VMs:
              $ pvectl stop vm --all -l status=running --yes

            Stop with sync wait:
              $ pvectl stop vm 100 --wait --timeout 30

          NOTES
            Hard stop may cause data loss or filesystem corruption in the guest.
            Prefer 'shutdown' for production workloads.

            Batch operations (--all) require --yes or interactive confirmation.

          SEE ALSO
            pvectl help shutdown        Graceful shutdown (recommended)
            pvectl help start           Start resources
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :stop do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = case resource_type
            when "container", "ct"
              StopContainer.execute(resource_type, resource_ids, options, global_options)
            else
              execute(resource_type, resource_ids, options, global_options)
            end
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :stop
    end
  end
end
