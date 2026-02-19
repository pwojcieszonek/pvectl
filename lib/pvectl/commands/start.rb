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
