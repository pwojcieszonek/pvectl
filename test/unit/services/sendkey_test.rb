# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SendkeyTest < Minitest::Test
      # ------------------------------------------------------------------
      # #execute — successful flow
      # ------------------------------------------------------------------

      def test_execute_invokes_repository_with_resolved_node_and_key
        vm = build_vm(vmid: 100, name: "web", node: "pve1", status: "running")
        repo = mock_repository(vm: vm, recorded_calls: (calls = []))

        service = Sendkey.new(vm_repository: repo)
        result = service.execute(vmid: 100, key: "ctrl-alt-delete")

        assert_equal [[100, "pve1", "ctrl-alt-delete"]], calls
        assert_instance_of Models::VmOperationResult, result
        assert result.successful?
        assert_equal :sendkey, result.operation
        assert_same vm, result.vm
      end

      def test_execute_passes_node_override_to_repository
        vm = build_vm(vmid: 100, name: "web", node: "pve3", status: "running")
        repo = mock_repository(vm: vm, recorded_calls: (calls = []))

        service = Sendkey.new(vm_repository: repo)
        service.execute(vmid: 100, key: "ret", node: "pve3")

        assert_equal [[100, "pve3", "ret"]], calls
      end

      def test_execute_resource_payload_includes_key_and_node
        vm = build_vm(vmid: 100, name: "web", node: "pve1", status: "running")
        repo = mock_repository(vm: vm, recorded_calls: [])

        result = Sendkey.new(vm_repository: repo).execute(vmid: 100, key: "esc")

        assert_equal({ vmid: 100, node: "pve1", key: "esc" }, result.resource)
      end

      # ------------------------------------------------------------------
      # #execute — error paths
      # ------------------------------------------------------------------

      def test_execute_returns_failed_result_when_vm_not_found
        repo = mock_repository(vm: nil, recorded_calls: (calls = []))

        result = Sendkey.new(vm_repository: repo).execute(vmid: 999, key: "ret")

        assert_empty calls
        assert result.failed?
        assert_match(/VM 999 not found/, result.error)
      end

      def test_execute_returns_failed_result_when_vm_not_running
        vm = build_vm(vmid: 100, name: "web", node: "pve1", status: "stopped")
        repo = mock_repository(vm: vm, recorded_calls: (calls = []))

        result = Sendkey.new(vm_repository: repo).execute(vmid: 100, key: "ret")

        assert_empty calls
        assert result.failed?
        assert_match(/not running/i, result.error)
      end

      def test_execute_returns_failed_result_when_repository_raises
        vm = build_vm(vmid: 100, name: "web", node: "pve1", status: "running")
        repo = Object.new
        repo.define_singleton_method(:get) { |_id| vm }
        repo.define_singleton_method(:sendkey) do |_vmid, _node, _key|
          raise StandardError, "boom"
        end

        result = Sendkey.new(vm_repository: repo).execute(vmid: 100, key: "ret")

        assert result.failed?
        assert_equal "boom", result.error
      end

      # ------------------------------------------------------------------
      # Helpers
      # ------------------------------------------------------------------

      private

      def build_vm(vmid:, name:, node:, status:)
        Models::Vm.new(vmid: vmid, name: name, node: node, status: status)
      end

      def mock_repository(vm:, recorded_calls:)
        repo = Object.new
        repo.define_singleton_method(:get) { |_id| vm }
        repo.define_singleton_method(:sendkey) do |vmid, node, key|
          recorded_calls << [vmid, node, key]
          nil
        end
        repo
      end
    end
  end
end
