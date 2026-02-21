# frozen_string_literal: true

module Pvectl
  module Commands
    module Describe
      # Dispatcher for the `pvectl describe <resource_type> <name>` command.
      #
      # Uses EXISTING Get infrastructure:
      # - Commands::Get::ResourceRegistry for handler lookup
      # - Services::Get::ResourceService for orchestration
      # - Handlers call describe() instead of list()
      #
      # @example Basic usage
      #   Commands::Describe::Command.execute("node", "pve1", options, global_options)
      #
      class Command
        # Registers the describe command with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "Show detailed information about a resource"
          cli.arg_name "RESOURCE_TYPE NAME"
          cli.command :describe do |c|
            c.desc "Filter by node name (required for local storage)"
            c.flag [:node], arg_name: "NODE"

            c.action do |global_options, options, args|
              resource_type = args[0]
              resource_name = args[1]
              extra_args = args[2..] || []
              exit_code = execute(resource_type, resource_name, options, global_options, extra_args: extra_args)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the describe command.
        #
        # @param resource_type [String, nil] type of resource (e.g., "node")
        # @param resource_name [String, nil] name of resource to describe
        # @param options [Hash] command-specific options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(resource_type, resource_name, options, global_options, extra_args: [])
          new(resource_type, resource_name, options, global_options, extra_args: extra_args).execute
        end

        # Creates a new Describe command instance.
        #
        # @param resource_type [String, nil] type of resource
        # @param resource_name [String, nil] name of resource to describe
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @param registry [Class] registry class for dependency injection
        def initialize(resource_type, resource_name, options, global_options,
                       extra_args: [], registry: Get::ResourceRegistry)
          @resource_type = resource_type
          @resource_name = resource_name
          @options = options
          @global_options = global_options
          @extra_args = extra_args
          @registry = registry
        end

        # Executes the describe operation.
        #
        # @return [Integer] exit code
        def execute
          return missing_resource_type_error if @resource_type.nil?
          return missing_resource_name_error if @resource_name.nil?

          handler = @registry.for(@resource_type)
          return unknown_resource_error unless handler

          run_describe(handler)
          ExitCodes::SUCCESS
        rescue Pvectl::ResourceNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::NOT_FOUND
        rescue Timeout::Error => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        rescue Errno::ECONNREFUSED => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        rescue SocketError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        end

        private

        # Outputs error for missing resource type argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_type_error
          $stderr.puts "Error: resource type is required"
          $stderr.puts "Usage: pvectl describe RESOURCE_TYPE NAME"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for missing resource name argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_name_error
          $stderr.puts "Error: resource name is required"
          $stderr.puts "Usage: pvectl describe #{@resource_type} NAME"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for unknown resource type.
        #
        # @return [Integer] USAGE_ERROR exit code
        def unknown_resource_error
          $stderr.puts "Unknown resource type: #{@resource_type}"
          ExitCodes::USAGE_ERROR
        end

        # Runs the describe operation with the given handler.
        #
        # @param handler [ResourceHandler] the resource handler
        # @return [void]
        def run_describe(handler)
          service = Services::Get::ResourceService.new(
            handler: handler,
            format: @global_options[:output] || "table",
            color_enabled: determine_color_enabled
          )
          output = service.describe(name: @resource_name, node: @options[:node], args: @extra_args)
          puts output
        end

        # Determines if color output should be enabled.
        #
        # @return [Boolean] true if color should be enabled
        def determine_color_enabled
          explicit = @global_options[:color]
          return explicit unless explicit.nil?

          $stdout.tty?
        end
      end
    end
  end
end
