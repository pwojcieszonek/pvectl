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
