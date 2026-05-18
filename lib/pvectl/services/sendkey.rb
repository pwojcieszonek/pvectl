# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates QEMU monitor key-send operations for a single VM.
    #
    # Resolves the VM (and its node) via the repository, validates that the
    # target VM is running, and forwards the key sequence verbatim to the
    # Proxmox API. The key string is passed through unmodified — interpretation
    # is delegated to QEMU's qcode parser.
    #
    # @example Sending Ctrl+Alt+Delete to a running VM
    #   service = Sendkey.new(vm_repository: vm_repo)
    #   result = service.execute(vmid: 100, key: "ctrl-alt-delete")
    #   result.successful? #=> true
    #
    class Sendkey
      # Creates a new Sendkey service.
      #
      # @param vm_repository [Repositories::Vm] VM repository for lookup and key send
      def initialize(vm_repository:)
        @vm_repository = vm_repository
      end

      # Sends a QEMU key sequence to a VM.
      #
      # Looks up the VM (the +node+ kwarg is honored when provided, otherwise
      # the node is taken from the resolved VM). Returns a failed
      # +VmOperationResult+ when the VM cannot be found, is not running, or
      # the underlying API call raises.
      #
      # @param vmid [Integer, String] VM identifier
      # @param key [String] QEMU qcode key sequence (e.g., "ctrl-alt-delete")
      # @param node [String, nil] optional node override
      # @return [Models::VmOperationResult] result of the operation
      def execute(vmid:, key:, node: nil)
        vmid_int = vmid.to_i

        vm = @vm_repository.get(vmid_int)
        return not_found_result(vmid_int) unless vm

        target_node = node || vm.node
        return not_running_result(vm, target_node, key) unless vm.status == "running"

        @vm_repository.sendkey(vmid_int, target_node, key)

        success_result(vm, target_node, key)
      rescue StandardError => e
        failure_result(vm, target_node || vm&.node, key, e.message)
      end

      private

      # @param vmid [Integer]
      # @return [Models::VmOperationResult]
      def not_found_result(vmid)
        Models::VmOperationResult.new(
          operation: :sendkey,
          success: false,
          error: "VM #{vmid} not found",
          resource: { vmid: vmid }
        )
      end

      # @param vm [Models::Vm]
      # @param node [String]
      # @param key [String]
      # @return [Models::VmOperationResult]
      def not_running_result(vm, node, key)
        Models::VmOperationResult.new(
          vm: vm,
          operation: :sendkey,
          success: false,
          error: "VM #{vm.vmid} is not running (status: #{vm.status})",
          resource: { vmid: vm.vmid, node: node, key: key }
        )
      end

      # @param vm [Models::Vm]
      # @param node [String]
      # @param key [String]
      # @return [Models::VmOperationResult]
      def success_result(vm, node, key)
        Models::VmOperationResult.new(
          vm: vm,
          operation: :sendkey,
          success: true,
          resource: { vmid: vm.vmid, node: node, key: key }
        )
      end

      # @param vm [Models::Vm, nil]
      # @param node [String, nil]
      # @param key [String]
      # @param message [String]
      # @return [Models::VmOperationResult]
      def failure_result(vm, node, key, message)
        Models::VmOperationResult.new(
          vm: vm,
          operation: :sendkey,
          success: false,
          error: message,
          resource: { vmid: vm&.vmid, node: node, key: key }
        )
      end
    end
  end
end
