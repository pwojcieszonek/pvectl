# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl suspend` command.
    #
    # Suspends one or more virtual machines (hibernate).
    #
    # @example Suspend a single VM
    #   pvectl suspend vm 100
    #
    # @example Suspend with sync mode
    #   pvectl suspend vm 100 --wait
    #
    class Suspend
      include VmLifecycleCommand

      # Registers the suspend command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Suspend virtual machines (hibernate)"
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :suspend do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = execute(resource_type, resource_ids, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :suspend
    end
  end
end
