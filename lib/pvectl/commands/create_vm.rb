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

      # Registers the create command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Create a resource"
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :create do |c|
          # Snapshot-specific flags
          c.desc "Snapshot name (required for snapshots)"
          c.flag [:name], arg_name: "NAME"

          c.desc "Description/notes"
          c.flag [:description, :notes], arg_name: "TEXT"

          c.desc "Save VM memory state (QEMU only, snapshots)"
          c.switch [:vmstate], negatable: false

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

          # Shared VM/container flags
          c.desc "Number of CPU cores"
          c.flag [:cores], type: Integer, arg_name: "N"

          c.desc "Number of CPU sockets (VM)"
          c.flag [:sockets], type: Integer, arg_name: "N"

          c.desc "CPU model type (VM)"
          c.flag [:"cpu-type"], arg_name: "TYPE"

          c.desc "Enable NUMA (VM)"
          c.switch [:numa], negatable: false

          c.desc "Memory in MB"
          c.flag [:memory], type: Integer, arg_name: "MB"

          c.desc "Balloon minimum memory in MB (VM)"
          c.flag [:balloon], type: Integer, arg_name: "MB"

          c.desc "Disk config (VM, repeatable): storage=X,size=Y[,format=Z,...]"
          c.flag [:disk], arg_name: "CONFIG", multiple: true

          c.desc "SCSI controller type (VM)"
          c.flag [:scsihw], arg_name: "TYPE"

          c.desc "CD-ROM/ISO path (VM): storage:iso/name.iso"
          c.flag [:cdrom], arg_name: "ISO"

          c.desc "Network config (repeatable): VM: bridge=X[,model=Y,tag=Z], CT: bridge=X[,name=Y,ip=Z]"
          c.flag [:net], arg_name: "CONFIG", multiple: true

          c.desc "BIOS firmware (VM): seabios or ovmf"
          c.flag [:bios], arg_name: "TYPE"

          c.desc "Boot order (VM)"
          c.flag [:"boot-order"], arg_name: "ORDER"

          c.desc "Machine type (VM): q35, pc"
          c.flag [:machine], arg_name: "TYPE"

          c.desc "EFI disk config (VM): storage=X[,size=Y]"
          c.flag [:efidisk], arg_name: "CONFIG"

          c.desc "Cloud-init config (VM): user=X,password=Y,ip=dhcp,..."
          c.flag [:"cloud-init"], arg_name: "CONFIG"

          c.desc "Enable QEMU guest agent (VM)"
          c.switch [:agent], negatable: false

          c.desc "OS type (VM): l26, win11, other, etc."
          c.flag [:ostype], arg_name: "TYPE"

          c.desc "Tags (comma-separated)"
          c.flag [:tags], arg_name: "TAGS"

          c.desc "Resource pool"
          c.flag [:pool], arg_name: "POOL"

          c.desc "Start resource after creation"
          c.switch [:start], negatable: false

          c.desc "Force interactive wizard mode"
          c.switch [:interactive], negatable: true

          c.desc "Show what would happen without creating"
          c.switch [:"dry-run"], negatable: false

          c.desc "Target node"
          c.flag [:node], arg_name: "NODE"

          # Container-specific flags
          c.desc "Container hostname (container)"
          c.flag [:hostname], arg_name: "NAME"

          c.desc "OS template path (container): storage:vztmpl/name.tar.zst"
          c.flag [:ostemplate], arg_name: "TEMPLATE"

          c.desc "Root filesystem (container): storage=X,size=Y"
          c.flag [:rootfs], arg_name: "CONFIG"

          c.desc "Mountpoint (container, repeatable): mp=/path,storage=X,size=Y"
          c.flag [:mp], arg_name: "CONFIG", multiple: true

          c.desc "Swap in MB (container)"
          c.flag [:swap], type: Integer, arg_name: "MB"

          c.desc "Create privileged container (container, default: unprivileged)"
          c.switch [:privileged], negatable: false

          c.desc "LXC features (container): nesting=1,keyctl=1"
          c.flag [:features], arg_name: "FEATURES"

          c.desc "Root password (container)"
          c.flag [:password], arg_name: "PASSWORD"

          c.desc "SSH public keys file (container)"
          c.flag [:"ssh-public-keys"], arg_name: "FILE"

          c.desc "Start on boot (container)"
          c.switch [:onboot], negatable: false

          c.desc "Startup order spec (container)"
          c.flag [:startup], arg_name: "SPEC"

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args

            exit_code = case resource_type
            when "vm"
              Commands::CreateVm.execute(resource_ids, options, global_options)
            when "container", "ct"
              Commands::CreateContainer.execute(resource_ids, options, global_options)
            when "snapshot"
              Commands::CreateSnapshot.execute(resource_type, resource_ids, options, global_options)
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
