# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl delete backup` command.
    #
    # Deletes a backup identified by its full volume ID (volid).
    # Requires --yes flag for confirmation.
    #
    # @example Delete a backup
    #   pvectl delete backup local:backup/vzdump-qemu-100-2024_01_15.vma.zst --yes
    #
    class DeleteBackup
      # Executes the delete backup command.
      #
      # @param resource_type [String, nil] resource type (backup)
      # @param args [Array<String>, String, nil] backup volid
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(resource_type, args, options, global_options)
        new(resource_type, args, options, global_options).execute
      end

      # Initializes a delete backup command.
      #
      # @param resource_type [String, nil] resource type (backup)
      # @param args [Array<String>, String, nil] backup volid
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, args, options, global_options)
        @resource_type = resource_type
        @args = Array(args).compact
        @options = options
        @global_options = global_options
        @volid = @args.first
      end

      # Executes the delete backup command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (backup)") unless @resource_type == "backup"
        return usage_error("Backup volid is required") if @volid.nil? || @volid.empty?
        return usage_error("Confirmation required: use --yes to confirm deletion") unless @options[:yes]

        perform_operation
      end

      private

      # Performs the backup deletion operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        backup_repo = Pvectl::Repositories::Backup.new(connection)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::Backup.new(
          backup_repo: backup_repo,
          resource_resolver: resolver,
          task_repo: task_repo,
          options: service_options
        )

        result = service.delete(@volid)

        output_results([result])
        determine_exit_code([result])
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
