# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl create snapshot` command.
    #
    # Creates snapshots for one or more VMs/containers.
    # Supports multiple VMIDs with optional confirmation prompt.
    #
    # @example Create single snapshot
    #   pvectl create snapshot 100 --name before-upgrade
    #
    # @example Create snapshot for multiple VMs
    #   pvectl create snapshot 100 101 102 --name before-upgrade --description "Pre-upgrade"
    #
    # @example Create snapshot with VM memory state
    #   pvectl create snapshot 100 --name with-state --vmstate
    #
    class CreateSnapshot
      SUPPORTED_RESOURCES = %w[snapshot].freeze

      # Executes the create snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param resource_ids [Array<String>, String, nil] VM identifiers
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(resource_type, resource_ids, options, global_options)
        new(resource_type, resource_ids, options, global_options).execute
      end

      # Initializes a create snapshot command.
      #
      # @param resource_type [String, nil] resource type (snapshot)
      # @param resource_ids [Array<String>, String, nil] VM identifiers
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, resource_ids, options, global_options)
        @resource_type = resource_type
        @resource_ids = Array(resource_ids).compact.map(&:to_i)
        @options = options
        @global_options = global_options
      end

      # Executes the create snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (snapshot)") unless @resource_type
        return usage_error("Unsupported resource: #{@resource_type}") unless SUPPORTED_RESOURCES.include?(@resource_type)
        return usage_error("At least one VMID is required") if @resource_ids.empty?
        return usage_error("--name is required") unless @options[:name]

        perform_operation
      end

      private

      # Performs the snapshot creation operation.
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

        return ExitCodes::SUCCESS unless confirm_operation

        results = service.create(
          @resource_ids,
          name: @options[:name],
          description: @options[:description],
          vmstate: @options[:vmstate] || false
        )

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

      # Confirms multi-VMID operation with user.
      #
      # @return [Boolean] true if operation should proceed
      def confirm_operation
        return true if @resource_ids.size == 1
        return true if @options[:yes]

        $stdout.puts "You are about to create snapshot '#{@options[:name]}' for #{@resource_ids.size} VMs:"
        @resource_ids.each { |vmid| $stdout.puts "  - #{vmid}" }
        $stdout.puts ""
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
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
