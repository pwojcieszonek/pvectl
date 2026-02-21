# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl create vm` command.
    #
    # Includes CreateResourceCommand for shared workflow and overrides
    # template methods with VM-specific behavior.
    #
    # @example Flag-based creation
    #   pvectl create vm --name web --node pve1 --cores 4 --memory 4096
    #
    # @example With disk and network
    #   pvectl create vm 100 --name web --node pve1 \
    #     --disk storage=local-lvm,size=32G --net bridge=vmbr0
    #
    # @example Dry-run mode
    #   pvectl create vm --name web --node pve1 --dry-run
    #
    class CreateVm
      include CreateResourceCommand
      include SharedConfigParsers

      # Registers the create command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Create a resource"
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :create do |c|
          c.desc "Resource name"
          c.flag [:name], arg_name: "NAME"

          c.desc "Description/notes"
          c.flag [:description, :notes], arg_name: "TEXT"

          # Backup-specific flags
          c.desc "Target storage for backup"
          c.flag [:storage], arg_name: "STORAGE"

          c.desc "Backup mode (snapshot, suspend, stop)"
          c.default_value "snapshot"
          c.flag [:mode], arg_name: "MODE", must_match: %w[snapshot suspend stop]

          c.desc "Compression (zstd, gzip, lzo, 0 for none)"
          c.default_value "zstd"
          c.flag [:compress], arg_name: "TYPE"

          c.desc "Protect backup from deletion"
          c.switch [:protected], negatable: false

          # Common flags
          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.desc "Timeout in seconds for sync operations"
          c.flag [:timeout], type: Integer, arg_name: "SECONDS"

          c.desc "Force async mode (return task ID immediately)"
          c.switch [:async], negatable: false

          c.desc "Stop on first error (default: continue and report all)"
          c.switch [:"fail-fast"], negatable: false

          # Shared config flags (VM + container)
          SharedFlags.common_config(c)
          SharedFlags.vm_config(c)
          SharedFlags.container_config(c)

          c.desc "Resource pool"
          c.flag [:pool], arg_name: "POOL"

          c.desc "Force interactive wizard mode"
          c.switch [:interactive], negatable: true

          c.desc "Show what would happen without creating"
          c.switch [:"dry-run"], negatable: false

          # Container-specific create flags
          c.desc "Container hostname (container)"
          c.flag [:hostname], arg_name: "NAME"

          c.desc "OS template path (container): storage:vztmpl/name.tar.zst"
          c.flag [:ostemplate], arg_name: "TEMPLATE"

          # Sub-commands
          CreateSnapshot.register_subcommand(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args

            exit_code = case resource_type
            when "vm"
              Commands::CreateVm.execute(resource_ids, options, global_options)
            when "container", "ct"
              Commands::CreateContainer.execute(resource_ids, options, global_options)
            when "backup"
              # Map :description to :notes for backup if notes not set
              options[:notes] ||= options[:description]
              Commands::CreateBackup.execute(resource_type, resource_ids, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, snapshot, backup"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      private

      # @return [String] human label for VM resources
      def resource_label
        "VM"
      end

      # @return [String] human label for VM IDs
      def resource_id_label
        "VMID"
      end

      # @return [Boolean] true if --name is missing
      def required_params_missing?
        !@options[:name]
      end

      # @return [Object] VM creation wizard
      def build_wizard
        Pvectl::Wizards::CreateVm.new(@options, @global_options)
      end

      # @param connection [Connection] API connection
      # @param task_repo [Repositories::Task] task repository
      # @return [Services::CreateVm] VM creation service
      def build_create_service(connection, task_repo)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        Pvectl::Services::CreateVm.new(
          vm_repository: vm_repo,
          task_repository: task_repo,
          options: service_options
        )
      end

      # @param result [Models::VmOperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::VmOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
      end

      # Validates flags and performs flag-based creation.
      #
      # Overrides shared #perform_create to add VM-specific validation.
      #
      # @return [Integer] exit code
      def perform_create
        return usage_error("--name is required") unless @options[:name]

        super
      end

      # Extracts CLI options into a service params hash.
      #
      # Delegates VM config parsing to SharedConfigParsers#build_vm_config_params,
      # then adds create-specific parameters.
      #
      # @return [Hash] service-compatible parameters
      # @raise [ArgumentError] if parser validation fails
      def build_params_from_flags
        params = build_vm_config_params
        params[:name] = @options[:name]
        params[:node] = @options[:node] || resolve_default_node
        params[:description] = @options[:description]
        params[:pool] = @options[:pool]

        vmid = @args.first
        params[:vmid] = vmid.to_i if vmid

        params.compact
      end

      # @param params [Hash] VM creation parameters
      # @return [void]
      def display_resource_summary(params)
        $stdout.puts "  Name:      #{params[:name]}"
        $stdout.puts "  Node:      #{params[:node] || '(from context)'}"

        if params[:cores] || params[:sockets]
          $stdout.puts "  CPU:       #{params[:cores] || 1} cores, #{params[:sockets] || 1} socket(s)"
        end

        $stdout.puts "  Memory:    #{params[:memory] || 2048} MB"

        if params[:disks]
          params[:disks].each_with_index do |disk, i|
            $stdout.puts "  Disk#{i}:     #{disk[:storage]}, #{disk[:size]}"
          end
        end

        if params[:nets]
          params[:nets].each_with_index do |net, i|
            $stdout.puts "  Net#{i}:      #{net[:bridge]}, #{net[:model] || 'virtio'}"
          end
        end

        $stdout.puts "  OS Type:   #{params[:ostype]}" if params[:ostype]
        $stdout.puts "  BIOS:      #{params[:bios]}" if params[:bios]
        $stdout.puts "  CD-ROM:    #{params[:cdrom]}" if params[:cdrom]
        $stdout.puts "  Agent:     enabled" if params[:agent]
        $stdout.puts "  Tags:      #{params[:tags]}" if params[:tags]
        $stdout.puts "  Pool:      #{params[:pool]}" if params[:pool]
      end
    end
  end
end
