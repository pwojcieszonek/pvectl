# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config use-context` command.
      #
      # Switches the active context in the configuration file.
      # The context name must exist in the configuration.
      #
      # @example Usage
      #   pvectl config use-context production
      #   pvectl config use-context dev
      #
      class UseContext
        # Executes the use-context command.
        #
        # @param context_name [String] name of the context to switch to
        # @param global_options [Hash] global CLI options (includes :config path)
        # @return [Integer] exit code (0 for success)
        # @raise [Config::ContextNotFoundError] if context doesn't exist
        def self.execute(context_name, global_options)
          config_path = global_options[:config]
          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          service.use_context(context_name)

          puts "Switched to context \"#{context_name}\"."
          0
        rescue Pvectl::Config::ContextNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONFIG_ERROR
        end
      end
    end
  end
end
