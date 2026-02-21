# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl start` command.
    #
    # Starts one or more virtual machines.
    #
    # @example Start a single VM
    #   pvectl start vm 100
    #
    # @example Start with JSON output
    #   pvectl start vm 100 -o json
    #
    class Start
      include VmLifecycleCommand

      # Registers the start command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Start virtual machines or containers"
        cli.long_desc <<~HELP
          Start one or more virtual machines or containers. Supports single
          resource, multiple IDs, and batch operations with selectors.

          By default, operations run asynchronously (fire-and-forget). Use
          --wait to wait for completion, or --async to explicitly force async.

          EXAMPLES
            Start a single VM:
              $ pvectl start vm 100

            Start multiple VMs:
              $ pvectl start vm 100 101 102

            Start a container:
              $ pvectl start ct 200

            Start all stopped VMs on a node:
              $ pvectl start vm --all -l status=stopped --node pve1

            Wait for start to complete with timeout:
              $ pvectl start vm 100 --wait --timeout 60

          NOTES
            Batch operations (--all) require --yes or interactive confirmation.

            Use selectors (-l) to filter: status, name, tags, pool.
            Multiple selectors use AND logic.

          SEE ALSO
            pvectl help stop            Hard stop resources
            pvectl help shutdown        Graceful shutdown
            pvectl help get vms         List VMs and their status
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :start do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = case resource_type
            when "container", "ct"
              StartContainer.execute(resource_type, resource_ids, options, global_options)
            else
              execute(resource_type, resource_ids, options, global_options)
            end
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :start
    end
  end
end
