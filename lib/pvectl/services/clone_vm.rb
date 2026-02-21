# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates VM clone operations.
    #
    # Handles validation, auto-generation of VMID/name, and sync/async modes.
    # Supports both full clones and linked clones (templates only).
    #
    # @example Full clone with auto-generated VMID
    #   service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
    #   result = service.execute(vmid: 100)
    #
    # @example Linked clone to specific node
    #   service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
    #   result = service.execute(vmid: 100, linked: true, target_node: "pve2")
    #
    # @example Async clone with custom timeout
    #   service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo, options: { async: true })
    #   result = service.execute(vmid: 100, new_vmid: 200, name: "web-clone")
    #
    class CloneVm
      DEFAULT_TIMEOUT = 300

      # @return [Integer] Default timeout for start operations (seconds)
      START_TIMEOUT = 60

      # Creates a new CloneVm service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async)
      def initialize(vm_repository:, task_repository:, options: {})
        @vm_repository = vm_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes clone operation.
      #
      # Performs a two-step flow: clone the VM first, then optionally apply
      # config updates via PUT /nodes/{node}/qemu/{vmid}/config.
      #
      # @param vmid [Integer] Source VM identifier
      # @param node [String, nil] Source node (auto-detected from VM if nil)
      # @param new_vmid [Integer, nil] New VMID (auto-selected if nil)
      # @param name [String, nil] Name for clone (auto-generated if nil)
      # @param target_node [String, nil] Target node for clone
      # @param storage [String, nil] Target storage
      # @param linked [Boolean] Linked clone (default: false, requires template)
      # @param pool [String, nil] Resource pool
      # @param description [String, nil] Description
      # @param config_params [Hash] VM config parameters to apply after clone
      # @return [Models::OperationResult] Clone result
      def execute(vmid:, node: nil, new_vmid: nil, name: nil, target_node: nil,
                  storage: nil, linked: false, pool: nil, description: nil,
                  config_params: {})
        source_vm = @vm_repository.get(vmid)
        return vm_not_found_error(vmid) unless source_vm

        if linked && !source_vm.template?
          return linked_clone_error(source_vm)
        end

        node ||= source_vm.node
        new_vmid ||= @vm_repository.next_available_vmid
        name ||= generate_name(source_vm)

        clone_options = build_clone_options(
          name: name, target_node: target_node, storage: storage,
          linked: linked, pool: pool, description: description
        )

        upid = @vm_repository.clone(vmid, node, new_vmid, clone_options)
        resource_info = { new_vmid: new_vmid, name: name, node: target_node || node }

        if @options[:async]
          Models::VmOperationResult.new(
            vm: source_vm, operation: :clone,
            task_upid: upid, success: :pending,
            resource: resource_info
          )
        else
          task = @task_repository.wait(upid, timeout: timeout)

          unless task.successful?
            return Models::VmOperationResult.new(
              vm: source_vm, operation: :clone,
              task: task, success: task.successful?,
              resource: resource_info
            )
          end

          if config_params.any?
            apply_config_update(source_vm, new_vmid, resource_info[:node], config_params, resource_info)
          else
            start_vm(new_vmid, resource_info[:node]) if @options[:start]
            Models::VmOperationResult.new(
              vm: source_vm, operation: :clone,
              task: task, success: true,
              resource: resource_info
            )
          end
        end
      rescue StandardError => e
        Models::VmOperationResult.new(
          vm: source_vm, operation: :clone,
          success: false, error: e.message
        )
      end

      private

      # Generates clone name from source VM.
      #
      # @param source_vm [Models::Vm] Source VM
      # @return [String] Generated name
      def generate_name(source_vm)
        if source_vm.name && !source_vm.name.empty?
          "#{source_vm.name}-clone"
        else
          "vm-#{source_vm.vmid}-clone"
        end
      end

      # Builds clone options hash for repository call.
      #
      # @param name [String] Clone name
      # @param target_node [String, nil] Target node
      # @param storage [String, nil] Target storage
      # @param linked [Boolean] Linked clone flag
      # @param pool [String, nil] Resource pool
      # @param description [String, nil] Description
      # @return [Hash] Clone options
      def build_clone_options(name:, target_node:, storage:, linked:, pool:, description:)
        opts = { name: name, full: !linked }
        opts[:target] = target_node if target_node
        opts[:storage] = storage if storage
        opts[:pool] = pool if pool
        opts[:description] = description if description
        opts
      end

      # Applies config update to the cloned VM.
      #
      # Converts user-friendly params to Proxmox API format and calls
      # the repository update method. Returns partial result on failure.
      #
      # @param source_vm [Models::Vm] Source VM
      # @param new_vmid [Integer] Cloned VM identifier
      # @param node [String] Target node for the cloned VM
      # @param config_params [Hash] Config parameters to apply
      # @param resource_info [Hash] Resource info for result
      # @return [Models::VmOperationResult] Operation result
      def apply_config_update(source_vm, new_vmid, node, config_params, resource_info)
        api_params = build_config_api_params(config_params)
        @vm_repository.update(new_vmid, node, api_params)
        start_vm(new_vmid, node) if @options[:start]
        Models::VmOperationResult.new(
          vm: source_vm, operation: :clone,
          success: true, resource: resource_info
        )
      rescue StandardError => e
        Models::VmOperationResult.new(
          vm: source_vm, operation: :clone,
          success: :partial, resource: resource_info,
          error: "Cloned successfully, but config update failed: #{e.message}"
        )
      end

      # Builds Proxmox API parameters from user-friendly config options.
      #
      # Maps config keys to their Proxmox API equivalents. Does not include
      # name, description, or pool (those belong to the clone step).
      #
      # @param config_params [Hash] User-friendly config parameters
      # @return [Hash] Proxmox API parameters
      def build_config_api_params(config_params)
        params = {}
        params[:cores] = config_params[:cores] if config_params[:cores]
        params[:sockets] = config_params[:sockets] if config_params[:sockets]
        params[:cpu] = config_params[:cpu_type] if config_params[:cpu_type]
        params[:numa] = config_params[:numa] ? 1 : 0 unless config_params[:numa].nil?
        params[:memory] = config_params[:memory] if config_params[:memory]
        params[:balloon] = config_params[:balloon] if config_params[:balloon]
        add_disk_params(params, config_params[:disks]) if config_params[:disks]
        params[:scsihw] = config_params[:scsihw] if config_params[:scsihw]
        params[:cdrom] = config_params[:cdrom] if config_params[:cdrom]
        add_net_params(params, config_params[:nets]) if config_params[:nets]
        params[:bios] = config_params[:bios] if config_params[:bios]
        params[:boot] = "order=#{config_params[:boot_order]}" if config_params[:boot_order]
        params[:machine] = config_params[:machine] if config_params[:machine]
        params[:efidisk0] = config_params[:efidisk] if config_params[:efidisk]
        params.merge!(config_params[:cloud_init]) if config_params[:cloud_init]
        params[:agent] = config_params[:agent] ? "1" : "0" unless config_params[:agent].nil?
        params[:ostype] = config_params[:ostype] if config_params[:ostype]
        params[:tags] = config_params[:tags] if config_params[:tags]
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

      # Starts a VM after successful clone and config update.
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

      # Returns error for VM not found.
      #
      # @param vmid [Integer] VM identifier
      # @return [Models::OperationResult] Failed result
      def vm_not_found_error(vmid)
        Models::VmOperationResult.new(
          operation: :clone,
          success: false,
          error: "VM #{vmid} not found"
        )
      end

      # Returns error for linked clone of non-template VM.
      #
      # @param source_vm [Models::Vm] Source VM
      # @return [Models::OperationResult] Failed result
      def linked_clone_error(source_vm)
        Models::VmOperationResult.new(
          vm: source_vm, operation: :clone,
          success: false,
          error: "Linked clone requires VM to be a template. VM #{source_vm.vmid} is not a template"
        )
      end
    end
  end
end
