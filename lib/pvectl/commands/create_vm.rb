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
      # Parses +--disk+, +--net+, and +--cloud-init+ flags through
      # their respective parsers. All nil values are compacted out.
      #
      # @return [Hash] service-compatible parameters
      # @raise [ArgumentError] if parser validation fails
      def build_params_from_flags
        params = {
          name: @options[:name],
          node: @options[:node] || resolve_default_node,
          ostype: @options[:ostype],
          description: @options[:description],
          tags: @options[:tags],
          pool: @options[:pool],
          cores: @options[:cores],
          sockets: @options[:sockets],
          cpu_type: @options[:"cpu-type"],
          numa: @options[:numa],
          memory: @options[:memory],
          balloon: @options[:balloon],
          scsihw: @options[:scsihw],
          cdrom: @options[:cdrom],
          bios: @options[:bios],
          boot_order: @options[:"boot-order"],
          machine: @options[:machine],
          efidisk: @options[:efidisk],
          agent: @options[:agent]
        }

        vmid = @args.first
        params[:vmid] = vmid.to_i if vmid

        params[:disks] = parse_disks if @options[:disk]
        params[:nets] = parse_nets if @options[:net]
        params[:cloud_init] = parse_cloud_init if @options[:"cloud-init"]

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

      # Parses disk configuration strings through the DiskConfig parser.
      #
      # @return [Array<Hash>] parsed disk configurations
      # @raise [ArgumentError] if any disk string is invalid
      def parse_disks
        Array(@options[:disk]).map { |d| Parsers::DiskConfig.parse(d) }
      end

      # Parses network configuration strings through the NetConfig parser.
      #
      # @return [Array<Hash>] parsed network configurations
      # @raise [ArgumentError] if any net string is invalid
      def parse_nets
        Array(@options[:net]).map { |n| Parsers::NetConfig.parse(n) }
      end

      # Parses cloud-init configuration string and converts to Proxmox params.
      #
      # @return [Hash] Proxmox-compatible cloud-init parameters
      # @raise [ArgumentError] if the cloud-init string is invalid
      def parse_cloud_init
        config = Parsers::CloudInitConfig.parse(@options[:"cloud-init"])
        Parsers::CloudInitConfig.to_proxmox_params(config)
      end
    end
  end
end
