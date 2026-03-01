# frozen_string_literal: true

require "test_helper"

class PullConfigTest < Minitest::Test
  def setup
    @vm_repo = Minitest::Mock.new
    @ct_repo = Minitest::Mock.new
    @service = Pvectl::Services::PullConfig.new(
      vm_repository: @vm_repo,
      container_repository: @ct_repo
    )
  end

  def test_pull_single_vm
    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    config = { cores: 4, memory: 4096, name: "test" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, config, ["pve1", 100]

    result = @service.execute(type: :vm, ids: [100])

    assert_equal 1, result[:manifests].length
    manifest = result[:manifests].first
    assert_equal 100, manifest[:metadata][:vmid]
    assert_equal "test", manifest[:metadata][:name]
    assert_equal "pve1", manifest[:metadata][:node]
    assert manifest[:yaml].include?("VirtualMachine")
    assert manifest[:yaml].include?("apiVersion")
    @vm_repo.verify
  end

  def test_pull_multiple_vms
    vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    vm2 = Pvectl::Models::Vm.new(vmid: 101, name: "vm2", node: "pve1", status: "stopped")
    config1 = { cores: 4, name: "vm1" }
    config2 = { cores: 2, name: "vm2" }

    @vm_repo.expect :get, vm1, [100]
    @vm_repo.expect :fetch_config, config1, ["pve1", 100]
    @vm_repo.expect :get, vm2, [101]
    @vm_repo.expect :fetch_config, config2, ["pve1", 101]

    result = @service.execute(type: :vm, ids: [100, 101])

    assert_equal 2, result[:manifests].length
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_pull_vm_not_found
    @vm_repo.expect :get, nil, [999]

    result = @service.execute(type: :vm, ids: [999])

    assert_empty result[:manifests]
    assert_equal 1, result[:errors].length
    assert result[:errors].first.include?("999")
    @vm_repo.verify
  end

  def test_pull_all_vms
    vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    vm2 = Pvectl::Models::Vm.new(vmid: 101, name: "vm2", node: "pve1", status: "stopped")
    config1 = { cores: 4, name: "vm1" }
    config2 = { cores: 2, name: "vm2" }

    @vm_repo.expect :list, [vm1, vm2], [], node: nil
    @vm_repo.expect :fetch_config, config1, ["pve1", 100]
    @vm_repo.expect :fetch_config, config2, ["pve1", 101]

    result = @service.execute(type: :vm, all: true)

    assert_equal 2, result[:manifests].length
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_pull_all_skips_templates
    vm = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    template = Pvectl::Models::Vm.new(vmid: 900, name: "template", node: "pve1", status: "stopped", template: 1)
    config = { cores: 4, name: "vm1" }

    @vm_repo.expect :list, [vm, template], [], node: nil
    @vm_repo.expect :fetch_config, config, ["pve1", 100]

    result = @service.execute(type: :vm, all: true)

    assert_equal 1, result[:manifests].length
    assert_equal 100, result[:manifests].first[:vmid]
    @vm_repo.verify
  end

  def test_pull_container
    ct = Pvectl::Models::Container.new(vmid: 200, name: "test-ct", hostname: "test-ct", node: "pve1", status: "running")
    config = { cores: 2, hostname: "test-ct" }

    @ct_repo.expect :get, ct, [200]
    @ct_repo.expect :fetch_config, config, ["pve1", 200]

    result = @service.execute(type: :container, ids: [200])

    assert_equal 1, result[:manifests].length
    manifest = result[:manifests].first
    assert_equal "test-ct", manifest[:metadata][:name]
    assert manifest[:yaml].include?("Container")
    @ct_repo.verify
  end

  def test_pull_with_node_filter
    vm = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    config = { cores: 4, name: "vm1" }

    @vm_repo.expect :list, [vm], [], node: "pve1"
    @vm_repo.expect :fetch_config, config, ["pve1", 100]

    result = @service.execute(type: :vm, all: true, node: "pve1")

    assert_equal 1, result[:manifests].length
    @vm_repo.verify
  end

  def test_pull_partial_failure
    vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    config1 = { cores: 4, name: "vm1" }

    @vm_repo.expect :get, vm1, [100]
    @vm_repo.expect :fetch_config, config1, ["pve1", 100]
    @vm_repo.expect :get, nil, [999]

    result = @service.execute(type: :vm, ids: [100, 999])

    assert_equal 1, result[:manifests].length
    assert_equal 1, result[:errors].length
    @vm_repo.verify
  end
end
