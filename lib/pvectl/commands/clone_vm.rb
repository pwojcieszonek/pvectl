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
      include SharedConfigParsers

      # Registers the clone command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Clone a resource"
        cli.long_desc <<~HELP
          Clone a virtual machine or container, optionally modifying the
          configuration of the clone (CPU, memory, disks, network).

          Supports full clones (independent copy) and linked clones (shares
          base image with source — requires source to be a template).

          EXAMPLES
            Clone a VM to the same node:
              $ pvectl clone vm 100 --name web-clone

            Clone to a different node:
              $ pvectl clone vm 100 --name web-prod --target pve2

            Clone with modified configuration:
              $ pvectl clone vm 100 --name web-prod --cores 4 --memory 8192

            Linked clone (thin provisioning, requires template):
              $ pvectl clone vm 100 --linked --name thin-clone

            Clone a container with new network config:
              $ pvectl clone ct 200 --name db-clone --memory 4096 --net bridge=vmbr1

            Clone with explicit new ID:
              $ pvectl clone vm 100 --newid 150 --name web-test

          NOTES
            Config modification is a two-step process: clone first, then update
            configuration via the Proxmox API. If the config update fails, the
            clone still exists but with the original configuration.

            Linked clones share the base disk with the source. They are faster
            to create and use less storage, but the source cannot be deleted.

            If --name is not specified, Proxmox auto-generates a name.

          SEE ALSO
            pvectl help create          Create new VMs/containers from scratch
            pvectl help migrate         Move resources between nodes
            pvectl help template        Convert to template for linked clones
        HELP
        cli.arg_name "RESOURCE_TYPE ID"
        cli.command :clone do |c|
          c.desc "Name/hostname for the new resource"
          c.flag [:name, :n], arg_name: "NAME"

          c.desc "ID for the new resource (auto-selected if not specified)"
          c.flag [:newid], type: Integer, arg_name: "ID"

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

          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          # Shared config flags for VM/container modification after clone
          SharedFlags.common_config(c)
          SharedFlags.vm_config(c)
          SharedFlags.container_config(c)

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
      # Builds config params from shared flags, validates async+config
      # compatibility, and delegates to the clone operation.
      #
      # @return [Integer] exit code
      def execute
        vmid = @args.first
        return usage_error("Source VMID required") unless vmid

        config_params = build_vm_config_params

        if @options[:async] && !config_params.empty?
          return usage_error("Config flags require sync mode (remove --async)")
        end

        perform_clone(vmid.to_i, config_params)
      end

      private

      # Performs the clone operation.
      #
      # When config params are present, displays a summary and prompts
      # for confirmation before proceeding. Passes config_params to the
      # service for the two-step clone+configure flow.
      #
      # @param vmid [Integer] source VM identifier
      # @param config_params [Hash] VM config parameters to apply after clone
      # @return [Integer] exit code
      def perform_clone(vmid, config_params)
        unless config_params.empty?
          return ExitCodes::SUCCESS if display_clone_summary(vmid, config_params) == :cancelled
        end

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
          new_vmid: @options[:newid]&.to_i,
          name: @options[:name],
          target_node: @options[:target],
          storage: @options[:storage],
          linked: @options[:linked],
          pool: @options[:pool],
          description: @options[:description],
          config_params: config_params
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
        opts[:start] = true if @options[:start]
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

      # Displays clone summary with config changes and prompts for confirmation.
      #
      # Only called when config params are present. Shows source/target info
      # and the config changes that will be applied after cloning.
      #
      # @param vmid [Integer] source VM identifier
      # @param config_params [Hash] config parameters to display
      # @return [Symbol, nil] +:cancelled+ if user declines, +nil+ otherwise
      def display_clone_summary(vmid, config_params)
        $stdout.puts ""
        $stdout.puts "  Clone VM - Summary"
        $stdout.puts "  #{'─' * 40}"
        $stdout.puts "  Source:    #{vmid}"
        $stdout.puts "  New ID:    #{@options[:newid] || '(auto)'}"
        $stdout.puts "  Name:      #{@options[:name] || '(auto)'}"
        target_display = @options[:target] ? "→ #{@options[:target]}" : "(same)"
        $stdout.puts "  Node:      #{target_display}"
        $stdout.puts "  Storage:   #{@options[:storage]}" if @options[:storage]
        display_config_changes(config_params)
        $stdout.puts "  #{'─' * 40}"
        $stdout.puts ""

        return nil if @options[:yes]

        $stdout.print "Clone and configure this VM? [y/N] "
        $stdout.flush
        answer = $stdin.gets&.strip&.downcase
        answer == "y" ? nil : :cancelled
      end

      # Displays the config changes section of the clone summary.
      #
      # @param params [Hash] config parameters
      # @return [void]
      def display_config_changes(params)
        $stdout.puts "  ── Config changes #{'─' * 23}"
        $stdout.puts "  CPU:       #{params[:cores]} cores" if params[:cores]
        $stdout.puts "  Sockets:   #{params[:sockets]}" if params[:sockets]
        $stdout.puts "  Memory:    #{params[:memory]} MB" if params[:memory]
        if params[:disks]
          params[:disks].each_with_index do |d, i|
            $stdout.puts "  Disk#{i}:     #{d[:storage]}, #{d[:size]}"
          end
        end
        if params[:nets]
          params[:nets].each_with_index do |n, i|
            $stdout.puts "  Net#{i}:      #{n[:bridge]}"
          end
        end
        $stdout.puts "  OS Type:   #{params[:ostype]}" if params[:ostype]
        $stdout.puts "  Agent:     enabled" if params[:agent]
        $stdout.puts "  Tags:      #{params[:tags]}" if params[:tags]
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
