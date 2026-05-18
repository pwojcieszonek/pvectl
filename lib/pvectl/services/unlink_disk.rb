# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates disk unlinking from a VM configuration.
    #
    # Delegates to the VM repository to issue the unlink PUT request and
    # wraps the outcome in a {Models::VmOperationResult}. The underlying
    # Proxmox endpoint is synchronous and returns no UPID, so the result
    # captures success/failure synchronously.
    #
    # @example Soft unlink (keeps volume as unused[n])
    #   service = UnlinkDisk.new(repository: vm_repo)
    #   result = service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1")
    #
    # @example Hard delete via force
    #   service = UnlinkDisk.new(repository: vm_repo)
    #   result = service.execute(vmid: 100, node: "pve1", disk_ids: %w[scsi1 scsi2], force: true)
    #
    class UnlinkDisk
      # Creates a new UnlinkDisk service.
      #
      # @param repository [Repositories::Vm] VM repository
      def initialize(repository:)
        @repository = repository
      end

      # Unlinks one or more disks from the VM configuration.
      #
      # @param vmid [Integer] VM identifier
      # @param node [String] node name
      # @param disk_ids [Array<String>, String] disk identifiers
      # @param force [Boolean] physically remove the underlying volume(s)
      # @return [Models::VmOperationResult] operation result
      def execute(vmid:, node:, disk_ids:, force: false)
        @repository.unlink_disks(node, vmid, disk_ids, force: force)
        build_result(vmid, node, disk_ids, force, success: true)
      rescue StandardError => e
        build_result(vmid, node, disk_ids, force, success: false, error: e.message)
      end

      private

      # Builds a VmOperationResult.
      #
      # @param vmid [Integer] VM identifier
      # @param node [String] node name
      # @param disk_ids [Array<String>, String] disk identifiers
      # @param force [Boolean] force flag
      # @param attrs [Hash] additional result attributes (:success, :error)
      # @return [Models::VmOperationResult]
      def build_result(vmid, node, disk_ids, force, **attrs)
        vm = fetch_vm(vmid) || Models::Vm.new(vmid: vmid, node: node)
        Models::VmOperationResult.new(
          operation: :unlink_disk,
          vm: vm,
          resource: {
            vmid: vmid,
            node: node,
            disk_ids: format_disk_ids(disk_ids),
            force: force
          },
          **attrs
        )
      end

      # Fetches the VM model for the result, swallowing any lookup errors.
      #
      # @param vmid [Integer] VM identifier
      # @return [Models::Vm, nil] VM model or nil if unavailable
      def fetch_vm(vmid)
        @repository.get(vmid)
      rescue StandardError
        nil
      end

      # Formats disk_ids into a stable comma-separated representation.
      #
      # @param disk_ids [Array<String>, String] disk identifiers
      # @return [String] comma-separated disk ID list
      def format_disk_ids(disk_ids)
        Array(disk_ids).flat_map { |id| id.to_s.split(",") }.map(&:strip).reject(&:empty?).join(",")
      end
    end
  end
end
