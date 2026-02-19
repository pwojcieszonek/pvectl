# frozen_string_literal: true

require "json"
require "yaml"

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config view` command.
      #
      # Displays the current configuration with secrets masked.
      # Secrets (token-secret, password) are replaced with ********.
      #
      # @example Usage
      #   pvectl config view
      #   pvectl config view -o json
      #
      class View
        # Registers the view subcommand.
        #
        # @param parent [GLI::Command] parent config command
        # @return [void]
        def self.register_subcommand(parent)
          parent.desc "Display current configuration with masked secrets"
          parent.command :view do |view|
            view.action do |global_options, _options, _args|
              exit_code = execute(global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the view command.
        #
        # @param global_options [Hash] global CLI options (includes :config, :output)
        # @return [Integer] exit code (0 for success)
        def self.execute(global_options)
          config_path = global_options[:config]
          output_format = global_options[:output] || "yaml"

          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          masked_config = service.masked_config

          case output_format
          when "json"
            puts JSON.pretty_generate(masked_config)
          else
            # Default to YAML for human-readable output
            puts masked_config.to_yaml
          end

          0
        end
      end
    end
  end
end
