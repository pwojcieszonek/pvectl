# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates VM creation operations.
    #
    # Handles auto-VMID allocation, parameter building (mapping disk/net/cloud-init
    # configs to Proxmox API format), sync/async modes, and optional auto-start.
    #
    # @example Basic VM creation
    #   service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
    #   result = service.execute(name: "web-server", node: "pve1",
    #                            cores: 4, memory: 4096,
    #                            disks: [{ storage: "local-lvm", size: "32G" }])
    #
    # @example Async creation with auto-start
    #   service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo,
    #                          options: { async: true, start: true })
    #   result = service.execute(vmid: 200, name: "db-server", node: "pve1",
    #                            cores: 8, memory: 16384)
    #
    class CreateVm
      # @return [Integer] Default timeout for create operations (seconds)
      DEFAULT_TIMEOUT = 300

      # @return [Integer] Default timeout for start operations (seconds)
      START_TIMEOUT = 60

      # Creates a new CreateVm service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, start)
      def initialize(vm_repository:, task_repository:, options: {})
        @vm_repository = vm_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes VM creation operation.
      #
      # @param vmid [Integer, nil] VM identifier (auto-allocated if nil)
      # @param name [String] VM name
      # @param node [String] Target node
      # @param cores [Integer, nil] Number of CPU cores
      # @param sockets [Integer, nil] Number of CPU sockets
      # @param cpu_type [String, nil] CPU type (e.g. "host", "kvm64")
      # @param numa [Boolean, nil] Enable NUMA
      # @param memory [Integer, nil] Memory in MB
      # @param balloon [Integer, nil] Balloon memory in MB
      # @param disks [Array<Hash>, nil] Disk configurations
      # @param scsihw [String, nil] SCSI controller type
      # @param cdrom [String, nil] CD-ROM ISO path
      # @param nets [Array<Hash>, nil] Network configurations
      # @param bios [String, nil] BIOS type (seabios or ovmf)
      # @param boot_order [String, nil] Boot order (e.g. "scsi0;net0")
      # @param machine [String, nil] Machine type (e.g. "q35")
      # @param efidisk [String, nil] EFI disk specification
      # @param cloud_init [Hash, nil] Cloud-init parameters
      # @param agent [Boolean, nil] Enable QEMU guest agent
      # @param ostype [String, nil] OS type (e.g. "l26", "win10")
      # @param description [String, nil] VM description
      # @param tags [String, nil] Tags (semicolon-separated)
      # @param pool [String, nil] Resource pool
      # @return [Models::VmOperationResult] Creation result
      def execute(vmid: nil, name:, node:, cores: nil, sockets: nil, cpu_type: nil,
                  numa: nil, memory: nil, balloon: nil, disks: nil, scsihw: nil,
                  cdrom: nil, nets: nil, bios: nil, boot_order: nil, machine: nil,
                  efidisk: nil, cloud_init: nil, agent: nil, ostype: nil,
                  description: nil, tags: nil, pool: nil)
        vmid ||= @vm_repository.next_available_vmid

        params = build_params(
          name: name, cores: cores, sockets: sockets, cpu_type: cpu_type,
          numa: numa, memory: memory, balloon: balloon, disks: disks,
          scsihw: scsihw, cdrom: cdrom, nets: nets, bios: bios,
          boot_order: boot_order, machine: machine, efidisk: efidisk,
          cloud_init: cloud_init, agent: agent, ostype: ostype,
          description: description, tags: tags, pool: pool
        )

        upid = @vm_repository.create(node, vmid, params)
        resource_info = { vmid: vmid, name: name, node: node }

        if @options[:async]
          build_result(resource_info, task_upid: upid, success: :pending)
        else
          task = @task_repository.wait(upid, timeout: timeout)
          start_vm(vmid, node) if task.successful? && @options[:start]
          build_result(resource_info, task: task, success: task.successful?)
        end
      rescue StandardError => e
        build_result({ vmid: vmid, name: name, node: node },
                     success: false, error: e.message)
      end

      private

      # Builds Proxmox API parameters from user-friendly options.
      #
      # Maps disk configs through {Parsers::DiskConfig.to_proxmox} and
      # network configs through {Parsers::NetConfig.to_proxmox}.
      #
      # @return [Hash] Proxmox API parameters
      def build_params(name:, cores:, sockets:, cpu_type:, numa:, memory:,
                       balloon:, disks:, scsihw:, cdrom:, nets:, bios:,
                       boot_order:, machine:, efidisk:, cloud_init:, agent:,
                       ostype:, description:, tags:, pool:)
        params = { name: name }
        params[:cores] = cores if cores
        params[:sockets] = sockets if sockets
        params[:cpu] = cpu_type if cpu_type
        params[:numa] = numa ? 1 : 0 unless numa.nil?
        params[:memory] = memory if memory
        params[:balloon] = balloon if balloon
        add_disk_params(params, disks) if disks
        params[:scsihw] = scsihw if scsihw
        params[:cdrom] = cdrom if cdrom
        add_net_params(params, nets) if nets
        params[:bios] = bios if bios
        params[:boot] = "order=#{boot_order}" if boot_order
        params[:machine] = machine if machine
        params[:efidisk0] = efidisk if efidisk
        params.merge!(cloud_init) if cloud_init
        params[:agent] = agent ? "1" : "0" unless agent.nil?
        params[:ostype] = ostype if ostype
        params[:description] = description if description
        params[:tags] = tags if tags
        params[:pool] = pool if pool
        params
      end

      # Adds disk parameters mapped to scsi0, scsi1, etc.
      #
      # @param params [Hash] Parameters hash to modify
      # @param disks [Array<Hash>] Disk configurations
      # @return [void]
      def add_disk_params(params, disks)
        disks.each_with_index do |disk, index|
          params[:"scsi#{index}"] = Parsers::DiskConfig.to_proxmox(disk)
        end
      end

      # Adds network parameters mapped to net0, net1, etc.
      #
      # @param params [Hash] Parameters hash to modify
      # @param nets [Array<Hash>] Network configurations
      # @return [void]
      def add_net_params(params, nets)
        nets.each_with_index do |net, index|
          params[:"net#{index}"] = Parsers::NetConfig.to_proxmox(net)
        end
      end

      # Starts a VM after successful creation.
      #
      # @param vmid [Integer] VM identifier
      # @param node [String] Node name
      # @return [void]
      def start_vm(vmid, node)
        upid = @vm_repository.start(vmid, node)
        @task_repository.wait(upid, timeout: START_TIMEOUT)
      end

      # Returns configured timeout.
      #
      # @return [Integer] Timeout in seconds
      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end

      # Builds a VmOperationResult with the :create operation.
      #
      # Creates a minimal Vm model for presenter compatibility.
      #
      # @param resource_info [Hash] Resource info (vmid, name, node)
      # @param attrs [Hash] Additional result attributes
      # @return [Models::VmOperationResult] Operation result
      def build_result(resource_info, **attrs)
        vm = Models::Vm.new(
          vmid: resource_info[:vmid],
          name: resource_info[:name],
          node: resource_info[:node]
        )
        Models::VmOperationResult.new(
          operation: :create, vm: vm, resource: resource_info, **attrs
        )
      end
    end
  end
end
