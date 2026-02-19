# frozen_string_literal: true

module Pvectl
  module Commands
    # CLI registration for the `pvectl console` command.
    #
    # Opens an interactive terminal console to a VM or container via
    # WebSocket-based termproxy. Dispatches to {ConsoleVm} or {ConsoleCt}
    # based on the resource type argument.
    #
    # @example Open console to a VM
    #   pvectl console vm 100
    #
    # @example Open console to a container
    #   pvectl console ct 200
    #
    # @example Open console with explicit credentials
    #   pvectl console vm 100 --user root@pam --password secret
    #
    class Console
      # Supported resource type arguments.
      SUPPORTED_RESOURCES = %w[vm ct container].freeze

      # Registers the console command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Open interactive terminal console to a VM or container"
        cli.arg_name "RESOURCE_TYPE ID"
        cli.command :console do |c|
          c.desc "Filter by node name"
          c.flag [:node, :n], arg_name: "NODE"

          c.desc "Username for session authentication"
          c.flag [:user], arg_name: "USER"

          c.desc "Password for session authentication"
          c.flag [:password], arg_name: "PASSWORD"

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_id = args.shift

            unless resource_type && SUPPORTED_RESOURCES.include?(resource_type)
              $stderr.puts "Error: Resource type required (vm, ct)"
              exit Pvectl::ExitCodes::USAGE_ERROR
            end

            exit_code = case resource_type
            when "ct", "container"
              ConsoleCt.execute(resource_id, options, global_options)
            else
              ConsoleVm.execute(resource_id, options, global_options)
            end

            exit exit_code if exit_code != 0
          end
        end
      end
    end
  end
end
