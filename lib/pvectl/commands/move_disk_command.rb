# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared functionality for the move disk commands (move disk vm, move disk ct).
    #
    # Mirrors the structure of MigrateCommand but operates on a single resource
    # (VM or container) and a single disk/volume rather than a batch.
    #
    # @example Including in a command class
    #   class MoveDiskVm
    #     include MoveDiskCommand
    #     RESOURCE_TYPE = :vm
    #     SUPPORTED_RESOURCES = %w[vm].freeze
    #   end
    #
    module MoveDiskCommand
      # Allowed target formats for VM disks (per Proxmox API).
      VALID_FORMATS = %w[raw qcow2 vmdk].freeze

      # Class methods added when the module is included.
      module ClassMethods
        # Executes the move disk command.
        #
        # @param args [Array<String>] command-positional args ([id, disk])
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def execute(args, options, global_options)
          new(args, options, global_options).execute
        end
      end

      # Hook called when the module is included.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Initializes a move disk command.
      #
      # @param args [Array<String>] command-positional args ([id, disk])
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args).compact
        @options = options
        @global_options = global_options
      end

      # Executes the move disk command.
      #
      # @return [Integer] exit code
      def execute
        target = @options[:target]
        return usage_error("--target is required") if target.nil? || target.to_s.empty?

        return usage_error("#{id_label} and #{disk_label} are required") if @args.size < 2

        id_str, disk = @args[0], @args[1]

        unless id_str.to_s.match?(/\A\d+\z/)
          return usage_error("Invalid #{id_label}: #{id_str}")
        end

        if @options[:format]
          return usage_error("--format is not supported for containers") if resource_type_symbol == :container
          return usage_error("Invalid format: #{@options[:format]} (allowed: #{VALID_FORMATS.join(', ')})") unless VALID_FORMATS.include?(@options[:format])
        end

        perform_operation(id_str.to_i, disk, target)
      end

      private

      # Returns the resource type symbol (:vm or :container).
      #
      # @return [Symbol]
      def resource_type_symbol
        self.class::RESOURCE_TYPE
      end

      # Returns the human label for the resource ID ("VMID" or "CTID").
      #
      # @return [String]
      def id_label
        resource_type_symbol == :vm ? "VMID" : "CTID"
      end

      # Returns the human label for the disk/volume.
      #
      # @return [String]
      def disk_label
        resource_type_symbol == :vm ? "DISK" : "VOLUME"
      end

      # Performs the move operation: loads config, resolves resource, prompts,
      # invokes service, prints result.
      #
      # @param id [Integer] resource identifier
      # @param disk [String] disk/volume key
      # @param target [String] target storage
      # @return [Integer] exit code
      def perform_operation(id, disk, target)
        load_config
        connection = Pvectl::Connection.new(@config)

        resource = resolve_resource(connection, id)
        return resource_not_found(id) if resource.nil?

        return ExitCodes::SUCCESS unless confirm_operation(resource, disk, target)

        service = build_service(connection)
        result = service.execute(resource_type_symbol, resource,
                                 disk: disk, target_storage: target)

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

      # Resolves the single resource by ID using the appropriate repository.
      #
      # @param connection [Connection] API connection
      # @param id [Integer] resource ID
      # @return [Models::Vm, Models::Container, nil]
      def resolve_resource(connection, id)
        repo = resource_type_symbol == :vm ?
          Pvectl::Repositories::Vm.new(connection) :
          Pvectl::Repositories::Container.new(connection)
        repo.get(id)
      end

      # Builds the MoveDisk service with required dependencies.
      #
      # @param connection [Connection] API connection
      # @return [Services::MoveDisk]
      def build_service(connection)
        Pvectl::Services::MoveDisk.new(
          vm_repository: Pvectl::Repositories::Vm.new(connection),
          container_repository: Pvectl::Repositories::Container.new(connection),
          task_repository: Pvectl::Repositories::Task.new(connection),
          options: service_options
        )
      end

      # Builds service options from command options.
      #
      # @return [Hash]
      def service_options
        opts = {}
        opts[:format] = @options[:format] if @options[:format]
        opts[:delete_source] = true if @options[:"delete-source"]
        opts[:bandwidth] = @options[:bandwidth].to_i if @options[:bandwidth]
        opts[:wait] = true if @options[:wait]
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts
      end

      # Confirms the move operation with the user.
      #
      # @param resource [Models::Vm, Models::Container]
      # @param disk [String]
      # @param target [String]
      # @return [Boolean] true if the operation should proceed
      def confirm_operation(resource, disk, target)
        return true if @options[:yes]

        type_name = resource_type_symbol == :vm ? "VM" : "container"
        $stdout.puts "You are about to move #{disk} of #{type_name} #{resource.vmid} " \
                     "(#{resource.name || 'unnamed'}) on #{resource.node} to storage #{target}."
        $stdout.puts ""
        if @options[:"delete-source"]
          $stdout.puts "Source disk WILL be deleted after a successful copy."
        else
          $stdout.puts "Source disk will be kept as an unused entry."
        end
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

      # Outputs the operation result using the configured formatter.
      #
      # @param result [Models::OperationResult]
      # @return [void]
      def output_result(result)
        presenter = if resource_type_symbol == :vm
                      Pvectl::Presenters::VmOperationResult.new
                    else
                      Pvectl::Presenters::ContainerOperationResult.new
                    end
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
      end

      # Outputs usage error and returns the usage exit code.
      #
      # @param message [String]
      # @return [Integer]
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Outputs "not found" error and returns the not-found exit code.
      #
      # @param id [Integer]
      # @return [Integer]
      def resource_not_found(id)
        $stderr.puts "Error: No #{resource_type_symbol == :vm ? 'VM' : 'container'} found with ID #{id}"
        ExitCodes::NOT_FOUND
      end
    end
  end
end
