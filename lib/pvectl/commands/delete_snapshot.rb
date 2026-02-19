# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl delete snapshot` command.
    #
    # Deletes snapshots from one or more VMs/containers.
    # Requires --yes flag for confirmation.
    #
    # @example Delete single snapshot
    #   pvectl delete snapshot 100 before-upgrade --yes
    #
    # @example Delete snapshot from multiple VMs
    #   pvectl delete snapshot 100 101 102 before-upgrade --yes
    #
    # @example Force removal
    #   pvectl delete snapshot 100 before-upgrade --yes --force
    #
    class DeleteSnapshot
      SUPPORTED_RESOURCES = %w[snapshot].freeze

      # Executes the delete snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param args [Array<String>, String, nil] VMIDs followed by snapshot name
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(resource_type, args, options, global_options)
        new(resource_type, args, options, global_options).execute
      end

      # Initializes a delete snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param args [Array<String>, String, nil] VMIDs followed by snapshot name
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, args, options, global_options)
        @resource_type = resource_type
        @args = Array(args).compact
        @options = options
        @global_options = global_options
        parse_args!
      end

      # Executes the delete snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (snapshot)") unless @resource_type
        return usage_error("Unsupported resource: #{@resource_type}") unless SUPPORTED_RESOURCES.include?(@resource_type)
        return usage_error("At least one VMID and snapshot name required") if @vmids.empty? || @snapshot_name.nil?
        return usage_error("Confirmation required: use --yes to confirm deletion") unless @options[:yes]

        perform_operation
      end

      private

      # Parses arguments: last arg is snapshot name, rest are VMIDs.
      #
      # @return [void]
      def parse_args!
        if @args.size >= 2
          @snapshot_name = @args.last
          @vmids = @args[0..-2].map(&:to_i)
        else
          @snapshot_name = nil
          @vmids = []
        end
      end

      # Performs the snapshot deletion operation.
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

        results = service.delete(@vmids, @snapshot_name, force: @options[:force] || false)

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
        opts[:fail_fast] = true if @options[:"fail-fast"]
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
