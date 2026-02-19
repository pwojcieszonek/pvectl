# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Registers the `pvectl config` command group with all subcommands.
      #
      # @example
      #   Commands::Config::Command.register(cli)
      #
      class Command
        # Registers the config command and all subcommands with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "Manage pvectl configuration"
          cli.command :config do |c|
            UseContext.register_subcommand(c)
            GetContexts.register_subcommand(c)
            SetContext.register_subcommand(c)
            SetCluster.register_subcommand(c)
            SetCredentials.register_subcommand(c)
            View.register_subcommand(c)
          end
        end
      end
    end
  end
end
