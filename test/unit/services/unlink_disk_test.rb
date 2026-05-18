# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    # Tests for the UnlinkDisk service.
    #
    # Verifies the service delegates disk unlinking to the repository,
    # wraps the result in a VmOperationResult, and propagates the
    # force flag correctly.
    class UnlinkDiskTest < Minitest::Test
      def setup
        @vm = Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", status: "running", node: "pve1")
      end

      def test_invokes_repository_with_single_disk
        repo = build_mock_repo(vm: @vm)
        service = UnlinkDisk.new(repository: repo)

        service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1")

        assert_equal [["pve1", 100, "scsi1", { force: false }]], repo.calls
      end

      def test_invokes_repository_with_multiple_disks
        repo = build_mock_repo(vm: @vm)
        service = UnlinkDisk.new(repository: repo)

        service.execute(vmid: 100, node: "pve1", disk_ids: %w[scsi1 scsi2])

        assert_equal [["pve1", 100, %w[scsi1 scsi2], { force: false }]], repo.calls
      end

      def test_propagates_force_flag
        repo = build_mock_repo(vm: @vm)
        service = UnlinkDisk.new(repository: repo)

        service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1", force: true)

        assert_equal [["pve1", 100, "scsi1", { force: true }]], repo.calls
      end

      def test_returns_vm_operation_result_on_success
        repo = build_mock_repo(vm: @vm)
        service = UnlinkDisk.new(repository: repo)

        result = service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1")

        assert_instance_of Pvectl::Models::VmOperationResult, result
        assert result.successful?
        assert_equal :unlink_disk, result.operation
        assert_equal @vm, result.vm
      end

      def test_resource_includes_disk_ids_and_force
        repo = build_mock_repo(vm: @vm)
        service = UnlinkDisk.new(repository: repo)

        result = service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1,scsi2", force: true)

        assert_equal "scsi1,scsi2", result.resource[:disk_ids]
        assert_equal true, result.resource[:force]
        assert_equal 100, result.resource[:vmid]
        assert_equal "pve1", result.resource[:node]
      end

      def test_returns_failed_result_on_repository_error
        repo = build_failing_repo("API error")
        service = UnlinkDisk.new(repository: repo)

        result = service.execute(vmid: 100, node: "pve1", disk_ids: "scsi1")

        assert result.failed?
        assert_equal "API error", result.error
      end

      private

      # Builds a mock repository that records unlink_disks calls.
      #
      # @param vm [Models::Vm] VM model to return from get
      # @return [Object] mock repository
      def build_mock_repo(vm:)
        repo = Object.new
        recorded = []
        repo.define_singleton_method(:calls) { recorded }
        repo.define_singleton_method(:get) { |_vmid| vm }
        repo.define_singleton_method(:unlink_disks) do |node, vmid, disk_ids, **opts|
          recorded << [node, vmid, disk_ids, opts]
          nil
        end
        repo
      end

      # Builds a repository that raises StandardError on unlink_disks.
      #
      # @param message [String] error message to raise
      # @return [Object] mock repository
      def build_failing_repo(message)
        repo = Object.new
        repo.define_singleton_method(:get) { |_vmid| nil }
        repo.define_singleton_method(:unlink_disks) do |_node, _vmid, _disk_ids, **_opts|
          raise StandardError, message
        end
        repo
      end
    end
  end
end
