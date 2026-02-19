# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl restore backup` command.
    #
    # Restores a backup identified by its full volume ID (volid)
    # to a new or existing VM/container.
    # Requires --vmid and --yes flags.
    #
    # @example Restore a backup to new VM
    #   pvectl restore backup local:backup/vzdump-qemu-100-xxx.vma.zst --vmid 200 --yes
    #
    # @example Restore with overwrite
    #   pvectl restore backup local:backup/vzdump-qemu-100-xxx.vma.zst --vmid 100 --force --yes
    #
    class RestoreBackup
      # Registers the restore command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Restore a resource from backup"
        cli.arg_name "RESOURCE_TYPE VOLID"
        cli.command :restore do |c|
          c.desc "Target VMID (required)"
          c.flag [:vmid], arg_name: "VMID", type: Integer

          c.desc "Target storage"
          c.flag [:storage], arg_name: "STORAGE"

          c.desc "Overwrite existing VM/container"
          c.switch [:force], negatable: false

          c.desc "Start after restore"
          c.switch [:start], negatable: false

          c.desc "Regenerate unique properties (MAC, UUID)"
          c.switch [:unique], negatable: false

          c.desc "Skip confirmation prompt (REQUIRED)"
          c.switch [:yes, :y], negatable: false

          c.desc "Timeout in seconds"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Force async mode"
          c.switch [:async], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift
            volid = args.first

            exit_code = case resource_type
            when "backup"
              Commands::RestoreBackup.execute(resource_type, volid, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: backup"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the restore backup command.
      #
      # @param resource_type [String, nil] resource type (backup)
      # @param volid [String, nil] backup volume ID
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(resource_type, volid, options, global_options)
        new(resource_type, volid, options, global_options).execute
      end

      # Initializes a restore backup command.
      #
      # @param resource_type [String, nil] resource type (backup)
      # @param volid [String, nil] backup volume ID
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(resource_type, volid, options, global_options)
        @resource_type = resource_type
        @volid = volid
        @options = options
        @global_options = global_options
      end

      # Executes the restore backup command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Resource type required (backup)") unless @resource_type == "backup"
        return usage_error("Backup volid is required") if @volid.nil? || @volid.empty?
        return usage_error("--vmid is required") unless @options[:vmid]
        return usage_error("Confirmation required: use --yes to confirm restore") unless @options[:yes]

        perform_operation
      end

      private

      # Performs the backup restore operation.
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

        result = service.restore(
          @volid,
          vmid: @options[:vmid],
          storage: @options[:storage],
          force: @options[:force] || false,
          start: @options[:start] || false,
          unique: @options[:unique] || false
        )

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
