# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      # Dispatcher for the `pvectl logs <resource_type> <id>` command.
      #
      # Routes requests to appropriate log handlers:
      # - vm/ct: task history via Handlers::TaskLogs
      # - node: syslog via Handlers::Syslog (or journal with --journal)
      # - task: log lines via Handlers::TaskDetail
      #
      # @example Basic usage
      #   Commands::Logs::Command.execute("vm", "100", options, global_options)
      #
      class Command
        # VM/CT resource types that use TaskLogs handler.
        VM_CT_TYPES = %w[vm vms ct container containers cts].freeze

        # Node resource types.
        NODE_TYPES = %w[node nodes].freeze

        # Executes the logs command.
        #
        # @param resource_type [String, nil] type (vm, ct, node, task)
        # @param resource_id [String, nil] identifier (VMID, node name, UPID)
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(resource_type, resource_id, options, global_options)
          new(resource_type, resource_id, options, global_options).execute
        end

        # Creates a new Logs command instance.
        #
        # @param resource_type [String, nil] type of resource
        # @param resource_id [String, nil] resource identifier
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @param handler [Object, nil] override handler for testing
        # @param journal_handler [Object, nil] override journal handler for testing
        # @param registry [Class] registry for handler lookup
        def initialize(resource_type, resource_id, options, global_options,
                       handler: nil, journal_handler: nil,
                       registry: Logs::ResourceRegistry)
          @resource_type = resource_type
          @resource_id = resource_id
          @options = options
          @global_options = global_options
          @handler = handler
          @journal_handler = journal_handler
          @registry = registry
        end

        # Executes the logs operation.
        #
        # @return [Integer] exit code
        def execute
          return missing_resource_type_error if @resource_type.nil?
          return missing_resource_id_error if @resource_id.nil? || @resource_id.empty?

          handler = resolve_handler
          return unknown_resource_error unless handler

          models = fetch_data(handler)
          output = format_output(models, handler.presenter)
          puts output

          ExitCodes::SUCCESS
        rescue ResourceNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::NOT_FOUND
        rescue Pvectl::Config::ConfigNotFoundError,
               Pvectl::Config::InvalidConfigError,
               Pvectl::Config::ContextNotFoundError,
               Pvectl::Config::ClusterNotFoundError,
               Pvectl::Config::UserNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONFIG_ERROR
        rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        end

        private

        # Resolves the handler based on resource type and flags.
        #
        # @return [Object, nil] handler instance
        def resolve_handler
          return @handler if @handler

          if NODE_TYPES.include?(@resource_type) && @options[:journal]
            @journal_handler || Handlers::Journal.new
          else
            @registry.for(@resource_type)
          end
        end

        # Fetches data from the handler with appropriate parameters.
        #
        # @param handler [Object] the resolved handler
        # @return [Array<Object>] models
        def fetch_data(handler)
          if VM_CT_TYPES.include?(@resource_type)
            handler.list(
              vmid: @resource_id.to_i,
              resource_type: @resource_type,
              all_nodes: @options[:"all-nodes"] || false,
              limit: @options[:limit] || 50,
              since: @options[:since],
              until_time: @options[:until],
              type_filter: @options[:type],
              status_filter: @options[:status]
            )
          elsif NODE_TYPES.include?(@resource_type)
            handler.list(
              node: @resource_id,
              limit: @options[:limit] || 50,
              since: @options[:since],
              until_time: @options[:until],
              service: @options[:service]
            )
          elsif @resource_type == "task"
            handler.list(
              upid: @resource_id,
              start: 0,
              limit: @options[:limit] || 512
            )
          else
            handler.list
          end
        end

        # Outputs error for missing resource type argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_type_error
          $stderr.puts "Error: resource type is required"
          $stderr.puts "Usage: pvectl logs RESOURCE_TYPE ID [options]"
          $stderr.puts "Available resources: vm, ct, node, task"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for missing resource ID argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_id_error
          $stderr.puts "Error: resource ID is required"
          $stderr.puts "Usage: pvectl logs #{@resource_type} ID [options]"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for unknown resource type.
        #
        # @return [Integer] USAGE_ERROR exit code
        def unknown_resource_error
          $stderr.puts "Unknown resource type: #{@resource_type}"
          $stderr.puts "Available resources: vm, ct, node, task"
          ExitCodes::USAGE_ERROR
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
