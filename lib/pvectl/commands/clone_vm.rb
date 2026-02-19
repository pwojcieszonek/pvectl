# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl clone vm` command.
    #
    # Clones a VM by VMID, supporting full and linked clones,
    # custom name, target node, storage, pool, and description.
    # No batch operations - clones exactly one VM at a time.
    #
    # @example Full clone with auto-generated VMID
    #   pvectl clone vm 100
    #
    # @example Clone with custom name and target VMID
    #   pvectl clone vm 100 --vmid 200 --name web-clone
    #
    # @example Linked clone to different node
    #   pvectl clone vm 100 --linked --target pve2
    #
    class CloneVm
      # Registers the clone command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Clone a resource"
        cli.arg_name "RESOURCE_TYPE VMID"
        cli.command :clone do |c|
          c.desc "Name/hostname for the new resource"
          c.flag [:name, :n], arg_name: "NAME"

          c.desc "ID for the new resource (auto-selected if not specified)"
          c.flag [:vmid], type: Integer, arg_name: "ID"

          c.desc "Target node for the clone"
          c.flag [:target, :t], arg_name: "NODE"

          c.desc "Target storage for the clone"
          c.flag [:storage, :s], arg_name: "STORAGE"

          c.desc "Create a linked clone (requires source to be a template)"
          c.switch [:linked], negatable: false

          c.desc "Resource pool for the new resource"
          c.flag [:pool, :p], arg_name: "POOL"

          c.desc "Description for the new resource"
          c.flag [:description, :d], arg_name: "DESCRIPTION"

          c.desc "Timeout in seconds for sync operations (default: 300)"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Async mode (return task ID immediately)"
          c.switch [:async], negatable: false

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::CloneVm.execute(args, options, global_options)
            when "container", "ct"
              Commands::CloneContainer.execute(args, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, ct"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the clone VM command.
      #
      # @param args [Array<String>] command arguments (VMID)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a clone VM command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the clone VM command.
      #
      # @return [Integer] exit code
      def execute
        vmid = @args.first
        return usage_error("Source VMID required") unless vmid

        perform_clone(vmid.to_i)
      end

      private

      # Performs the clone operation.
      #
      # @param vmid [Integer] source VM identifier
      # @return [Integer] exit code
      def perform_clone(vmid)
        load_config
        connection = Pvectl::Connection.new(@config)

        vm_repo = Pvectl::Repositories::Vm.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::CloneVm.new(
          vm_repository: vm_repo,
          task_repository: task_repo,
          options: service_options
        )

        result = service.execute(
          vmid: vmid,
          new_vmid: @options[:vmid]&.to_i,
          name: @options[:name],
          target_node: @options[:target],
          storage: @options[:storage],
          linked: @options[:linked],
          pool: @options[:pool],
          description: @options[:description]
        )

        print_progress(result) if !@options[:async] && result.vm

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
      # @param result [Models::OperationResult] clone result
      # @return [void]
      def print_progress(result)
        source = result.vm
        new_name = result.resource&.dig(:name) || "clone"
        new_id = result.resource&.dig(:new_vmid)
        $stderr.puts "Cloning VM #{source.vmid} (#{source.name || 'unnamed'}) to #{new_id} (#{new_name})..."
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
      # @param result [Models::OperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::VmOperationResult.new
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
