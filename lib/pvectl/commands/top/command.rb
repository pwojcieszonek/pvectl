# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      # Dispatcher for the `pvectl top <resource_type>` command.
      #
      # Displays resource usage metrics (CPU, memory, disk, swap) for
      # cluster resources. Supports nodes, VMs, and containers.
      #
      # Uses Top::ResourceRegistry for handler lookup and Top-specific
      # presenters for metrics-focused display. VMs and containers are
      # filtered to running-only by default (use --all to show all).
      #
      # @example Basic usage
      #   Commands::Top::Command.execute("nodes", options, global_options)
      #
      class Command
        # Resource types where running-only filtering does NOT apply.
        SHOW_ALL_RESOURCE_TYPES = %w[nodes node].freeze

        # Executes the top command.
        #
        # @param resource_type [String, nil] type of resource (e.g., "nodes")
        # @param options [Hash] command-specific options
        #   - :"sort-by" [String] sort field (cpu, memory, disk)
        # @param global_options [Hash] global CLI options
        #   - :output [String] output format (table, json, yaml, wide)
        #   - :color [Boolean, nil] explicit color setting
        # @return [Integer] exit code
        def self.execute(resource_type, options, global_options)
          new(resource_type, options, global_options).execute
        end

        # Creates a new Top command instance.
        #
        # @param resource_type [String, nil] type of resource
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @param handler [Object, nil] override handler for testing
        # @param registry [Class] resource registry (default: Top::ResourceRegistry)
        def initialize(resource_type, options, global_options,
                       handler: nil, registry: Top::ResourceRegistry)
          @resource_type = resource_type
          @options = options
          @global_options = global_options
          @handler = handler
          @registry = registry
        end

        # Executes the top operation.
        #
        # @return [Integer] exit code
        def execute
          return missing_resource_type_error if @resource_type.nil?

          handler = @handler || @registry.for(@resource_type)
          return unknown_resource_error unless handler

          models = handler.list(sort: @options[:"sort-by"])
          models = filter_running(models) unless @options[:all]
          output = format_output(models, handler.presenter)
          puts output

          ExitCodes::SUCCESS
        rescue Pvectl::Config::ConfigNotFoundError,
               Pvectl::Config::InvalidConfigError,
               Pvectl::Config::ContextNotFoundError,
               Pvectl::Config::ClusterNotFoundError,
               Pvectl::Config::UserNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONFIG_ERROR
        rescue Timeout::Error => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        rescue Errno::ECONNREFUSED => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        rescue SocketError => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        end

        private

        # Outputs error for missing resource type argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_type_error
          $stderr.puts "Error: resource type is required"
          $stderr.puts "Usage: pvectl top RESOURCE_TYPE [options]"
          $stderr.puts "Available resources: nodes, vms, containers"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for unknown resource type.
        #
        # @return [Integer] USAGE_ERROR exit code
        def unknown_resource_error
          $stderr.puts "Unknown resource type: #{@resource_type}"
          $stderr.puts "Available resources: nodes, vms, containers"
          ExitCodes::USAGE_ERROR
        end

        # Filters models to running-only for VM/CT resource types.
        # Nodes always show all (offline nodes are important info).
        #
        # @param models [Array<Object>] models to filter
        # @return [Array<Object>] filtered models
        def filter_running(models)
          return models if SHOW_ALL_RESOURCE_TYPES.include?(@resource_type)
          return models unless models.first.respond_to?(:running?)

          models.select(&:running?)
        end

        # Outputs connection error message.
        #
        # @param message [String] the error message
        # @return [void]
        def output_connection_error(message)
          $stderr.puts "Error: #{message}"
        end

        # Formats models for output using the appropriate formatter.
        #
        # @param models [Array<Object>] collection of models
        # @param presenter [Presenters::Base] presenter for the resource type
        # @return [String] formatted output
        def format_output(models, presenter)
          format = @global_options[:output] || "table"
          color_enabled = determine_color_enabled
          formatter = Formatters::Registry.for(format)
          formatter.format(models, presenter, color_enabled: color_enabled)
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
