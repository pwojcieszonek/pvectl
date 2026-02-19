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
      # @param vmid [Integer] Source VM identifier
      # @param node [String, nil] Source node (auto-detected from VM if nil)
      # @param new_vmid [Integer, nil] New VMID (auto-selected if nil)
      # @param name [String, nil] Name for clone (auto-generated if nil)
      # @param target_node [String, nil] Target node for clone
      # @param storage [String, nil] Target storage
      # @param linked [Boolean] Linked clone (default: false, requires template)
      # @param pool [String, nil] Resource pool
      # @param description [String, nil] Description
      # @return [Models::OperationResult] Clone result
      def execute(vmid:, node: nil, new_vmid: nil, name: nil, target_node: nil,
                  storage: nil, linked: false, pool: nil, description: nil)
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
        resource_info = { new_vmid: new_vmid, name: name }

        if @options[:async]
          Models::VmOperationResult.new(
            vm: source_vm, operation: :clone,
            task_upid: upid, success: :pending,
            resource: resource_info
          )
        else
          task = @task_repository.wait(upid, timeout: timeout)
          Models::VmOperationResult.new(
            vm: source_vm, operation: :clone,
            task: task, success: task.successful?,
            resource: resource_info
          )
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
