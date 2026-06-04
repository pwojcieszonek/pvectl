# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SetVmTest < Minitest::Test
      def build_vm(attrs = {})
        Models::Vm.new({ vmid: 100, name: "test-vm", node: "pve1", status: "running" }.merge(attrs))
      end

      def build_config(extras = {})
        { memory: "4096", cores: "2", name: "test-vm", digest: "abc123" }.merge(extras)
      end

      def test_applies_changes_to_api
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])

        update_params = nil
        vm_repo.expect(:update, nil) do |vmid, node, params|
          update_params = params
          true
        end

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "8192" })

        assert result.successful?
        assert_equal :set, result.operation
        assert_kind_of Models::VmOperationResult, result
        assert_equal "8192", update_params[:memory]
        assert_equal "abc123", update_params[:digest]
        vm_repo.verify
      end

      def test_multiple_changes
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])

        update_params = nil
        vm_repo.expect(:update, nil) do |vmid, node, params|
          update_params = params
          true
        end

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "8192", cores: "4" })

        assert result.successful?
        assert_equal "8192", update_params[:memory]
        assert_equal "4", update_params[:cores]
        vm_repo.verify
      end

      def test_adds_new_key
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])

        update_params = nil
        vm_repo.expect(:update, nil) do |vmid, node, params|
          update_params = params
          true
        end

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { description: "new desc" })

        assert result.successful?
        assert_equal "new desc", update_params[:description]
        vm_repo.verify
      end

      def test_dry_run_does_not_call_api
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])
        # NO update expectation — dry run should NOT call update

        service = SetVm.new(vm_repository: vm_repo, options: { dry_run: true })
        result = service.execute(vmid: 100, params: { memory: "8192" })

        assert result.successful?
        assert result.resource[:diff]
        refute_empty result.resource[:diff][:changed]
        vm_repo.verify
      end

      def test_no_changes_returns_nil
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "4096" })

        assert_nil result
        vm_repo.verify
      end

      def test_vm_not_found
        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, nil, [100])

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "8192" })

        assert result.failed?
        assert_match(/not found/, result.error)
        assert_kind_of Models::VmOperationResult, result
        vm_repo.verify
      end

      def test_execute_resolves_vm_by_name
        vm = Struct.new(:vmid, :node, :status).new(100, "pve1", "running")
        repo = Object.new
        repo.define_singleton_method(:resolve_one) { |id| id == "web" ? vm : nil }
        repo.define_singleton_method(:fetch_config) { |_node, _vmid| { memory: "2048" } }
        captured = {}
        repo.define_singleton_method(:update) { |vmid, node, params| captured[:vmid] = vmid }

        service = Pvectl::Services::SetVm.new(vm_repository: repo)
        result = service.execute(vmid: "web", params: { "memory" => "4096" })

        assert result.successful?
        assert_equal 100, captured[:vmid]  # resolved to the integer VMID
      end

      def test_execute_rejects_rename_to_existing_name
        vm = Struct.new(:vmid, :node, :status).new(100, "pve1", "running")
        repo = Object.new
        repo.define_singleton_method(:resolve_one) { |_id| vm }
        repo.define_singleton_method(:fetch_config) { |_n, _v| { name: "old" } }
        repo.define_singleton_method(:update) { |*| flunk "update should not run on duplicate name" }
        resolver = Object.new
        resolver.define_singleton_method(:name_conflicts) do |_name, except_vmid: nil|
          except_vmid == 100 ? [{ vmid: 105, node: "pve2" }] : []
        end

        service = Pvectl::Services::SetVm.new(vm_repository: repo, name_resolver: resolver)
        result = service.execute(vmid: 100, params: { "name" => "taken" })

        refute result.successful?
        assert_match(/already exists/, result.error)
      end

      def test_api_error
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])
        vm_repo.expect(:update, nil) do |_vmid, _node, _params|
          raise StandardError, "API timeout"
        end

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "8192" })

        assert result.failed?
        assert_match(/API timeout/, result.error)
        vm_repo.verify
      end

      def test_diff_contains_changes
        vm = build_vm
        config = build_config

        vm_repo = Minitest::Mock.new
        vm_repo.expect(:resolve_one, vm, [100])
        vm_repo.expect(:fetch_config, config, ["pve1", 100])

        _update_params = nil
        vm_repo.expect(:update, nil) do |vmid, node, params|
          _update_params = params
          true
        end

        service = SetVm.new(vm_repository: vm_repo)
        result = service.execute(vmid: 100, params: { memory: "8192", description: "new" })

        diff = result.resource[:diff]
        assert_includes diff[:changed].keys, :memory
        assert_includes diff[:added].keys, :description
        vm_repo.verify
      end
    end
  end
end
