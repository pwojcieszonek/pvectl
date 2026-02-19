# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl clone container` command.
    #
    # Clones a container by CTID, supporting full and linked clones,
    # custom hostname, target node, storage, pool, and description.
    # No batch operations - clones exactly one container at a time.
    #
    # @example Full clone with auto-generated CTID
    #   pvectl clone container 100
    #
    # @example Clone with custom hostname and target CTID
    #   pvectl clone container 100 --vmid 200 --name web-clone
    #
    # @example Linked clone to different node
    #   pvectl clone container 100 --linked --target pve2
    #
    class CloneContainer
      # Executes the clone container command.
      #
      # @param args [Array<String>] command arguments (CTID)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a clone container command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the clone container command.
      #
      # @return [Integer] exit code
      def execute
        ctid = @args.first
        return usage_error("Source CTID required") unless ctid

        perform_clone(ctid.to_i)
      end

      private

      # Performs the clone operation.
      #
      # @param ctid [Integer] source container identifier
      # @return [Integer] exit code
      def perform_clone(ctid)
        load_config
        connection = Pvectl::Connection.new(@config)

        ct_repo = Pvectl::Repositories::Container.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::CloneContainer.new(
          container_repository: ct_repo,
          task_repository: task_repo,
          options: service_options
        )

        result = service.execute(
          ctid: ctid,
          new_ctid: @options[:vmid]&.to_i,
          hostname: @options[:name],
          target_node: @options[:target],
          storage: @options[:storage],
          linked: @options[:linked],
          pool: @options[:pool],
          description: @options[:description]
        )

        print_progress(result) if !@options[:async] && result.container

        output_result(result)
        result.failed? ? ExitCodes::GENERAL_ERROR : ExitCodes::SUCCESS
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

      # Prints progress message for sync mode.
      #
      # @param result [Models::ContainerOperationResult] clone result
      # @return [void]
      def print_progress(result)
        source = result.container
        new_hostname = result.resource&.dig(:hostname) || "clone"
        new_id = result.resource&.dig(:new_ctid)
        $stderr.puts "Cloning container #{source.vmid} (#{source.name || 'unnamed'}) to #{new_id} (#{new_hostname})..."
        $stderr.puts ""
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

      # Outputs operation result using the configured formatter.
      #
      # @param result [Models::ContainerOperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::ContainerOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
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
