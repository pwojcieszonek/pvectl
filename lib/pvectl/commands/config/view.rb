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
