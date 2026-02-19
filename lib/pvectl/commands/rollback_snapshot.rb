# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl rollback snapshot` command.
    #
    # Rolls back a VM/container to a snapshot.
    # Requires --yes flag for confirmation. Only supports single VMID.
    #
    # @example Rollback to snapshot
    #   pvectl rollback snapshot 100 before-upgrade --yes
    #
    # @example Start after rollback (LXC only)
    #   pvectl rollback snapshot 100 before-upgrade --yes --start
    #
    class RollbackSnapshot
      # Registers the rollback command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Rollback to a snapshot"
        cli.arg_name "RESOURCE_TYPE VMID SNAPSHOT_NAME"
        cli.command :rollback do |c|
          c.desc "Skip confirmation prompt (REQUIRED for destructive operations)"
          c.switch [:yes, :y], negatable: false

          c.desc "Start VM/container after rollback (LXC only)"
          c.switch [:start], negatable: false

          c.desc "Timeout in seconds for sync operations"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Force async mode (return task ID immediately)"
          c.switch [:async], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift
            exit_code = Commands::RollbackSnapshot.execute(
              resource_type,
              args,
              options,
              global_options
            )
            exit exit_code if exit_code != 0
          end
        end
      end

      SUPPORTED_RESOURCES = %w[snapshot].freeze

      # Executes the rollback snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param args [Array<String>, String, nil] VMID and snapshot name
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(resource_type, args, options, global_options)
        new(resource_type, args, options, global_options).execute
      end

      # Initializes a rollback snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param args [Array<String>, String, nil] VMID and snapshot name
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, args, options, global_options)
        @resource_type = resource_type
        @args = Array(args).compact
        @options = options
        @global_options = global_options
        @too_many_args = false
        parse_args!
      end

      # Executes the rollback snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (snapshot)") unless @resource_type
        return usage_error("Unsupported resource: #{@resource_type}") unless SUPPORTED_RESOURCES.include?(@resource_type)
        return usage_error("Rollback supports only single VMID") if @too_many_args
        return usage_error("VMID and snapshot name required") if @vmid.nil? || @snapshot_name.nil?
        return usage_error("Confirmation required: use --yes to confirm rollback") unless @options[:yes]

        perform_operation
      end

      private

      # Parses arguments: exactly 2 args - VMID and snapshot name.
      #
      # @return [void]
      def parse_args!
        if @args.size == 2
          @vmid = @args[0].to_i
          @snapshot_name = @args[1]
        elsif @args.size > 2
          # Too many args - rollback only supports single VMID
          @vmid = nil
          @snapshot_name = nil
          @too_many_args = true
        else
          @vmid = nil
          @snapshot_name = nil
        end
      end

      # Performs the snapshot rollback operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::Snapshot.new(
          snapshot_repo: snapshot_repo,
          resource_resolver: resolver,
          task_repo: task_repo,
          options: service_options
        )

        result = service.rollback(@vmid, @snapshot_name, start: @options[:start] || false)
        results = [result]

        output_results(results)
        determine_exit_code(results)
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options from command options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts
      end

      # Outputs operation results using the configured formatter.
      #
      # @param results [Array<Models::OperationResult>] operation results
      # @return [void]
      def output_results(results)
        presenter = Pvectl::Presenters::SnapshotOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format(results, presenter, color: color_flag)
        puts output
      end

      # Determines exit code based on results.
      #
      # @param results [Array<Models::OperationResult>] operation results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return ExitCodes::SUCCESS if results.all?(&:successful?)
        return ExitCodes::SUCCESS if results.all?(&:pending?)

        ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error and returns exit code.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
