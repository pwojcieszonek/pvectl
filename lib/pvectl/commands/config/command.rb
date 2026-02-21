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
          cli.long_desc <<~HELP
            Manage pvectl configuration. Configuration uses kubeconfig-style
            contexts to support multiple Proxmox clusters.

            Configuration file location: ~/.pvectl/config

            SUBCOMMANDS
              config get-contexts       List all available contexts
              config use-context NAME   Switch to a different context
              config set-context NAME   Create or modify a context
              config set-cluster NAME   Create or modify a cluster definition
              config set-credentials NAME  Create or modify user credentials
              config view               Display current configuration (secrets masked)

            EXAMPLES
              View current configuration:
                $ pvectl config view

              Switch to a different context:
                $ pvectl config use-context production

              Set up a new cluster:
                $ pvectl config set-cluster prod --server=https://pve.example.com:8006
                $ pvectl config set-credentials admin --token-id=root@pam!pvectl --token-secret=xxx
                $ pvectl config set-context prod --cluster=prod --user=admin

            NOTES
              On first run, pvectl launches an interactive wizard if no config exists.

              Environment variables (PROXMOX_HOST, PROXMOX_TOKEN_ID, etc.) override
              config file values. Use PVECTL_CONTEXT to override the active context.

            SEE ALSO
              pvectl help ping          Test connectivity after configuration
          HELP
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
