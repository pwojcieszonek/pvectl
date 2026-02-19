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
