# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config get-contexts` command.
      #
      # Lists all contexts defined in the configuration file with
      # an indicator showing which context is currently active.
      # Uses the unified OutputHelper for formatting output.
      #
      # @example Usage
      #   pvectl config get-contexts
      #   pvectl config get-contexts -o json
      #   pvectl config get-contexts -o yaml
      #   pvectl config get-contexts -o wide
      #   pvectl config get-contexts --no-color
      #
      class GetContexts
        # Registers the get-contexts subcommand.
        #
        # @param parent [GLI::Command] parent config command
        # @return [void]
        def self.register_subcommand(parent)
          parent.desc "List all available contexts"
          parent.long_desc <<~HELP
            List all contexts defined in the configuration file. The currently
            active context is marked with an asterisk (*).

            EXAMPLES
              $ pvectl config get-contexts
          HELP
          parent.command :"get-contexts" do |get_ctx|
            get_ctx.action do |global_options, _options, _args|
              exit_code = execute(global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the get-contexts command.
        #
        # @param global_options [Hash] global CLI options (includes :config, :output, :color)
        # @return [Integer] exit code (0 for success)
        def self.execute(global_options)
          config_path = global_options[:config]

          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          contexts = service.contexts
          current_context_name = service.current_context_name
          presenter = Pvectl::Presenters::Config::Context.new

          Pvectl::Formatters::OutputHelper.print(
            data: contexts,
            presenter: presenter,
            format: global_options[:output] || "table",
            color_flag: global_options[:color],
            current_context: current_context_name
          )

          0
        end
      end
    end
  end
end
