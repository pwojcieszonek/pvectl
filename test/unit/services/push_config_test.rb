# frozen_string_literal: true

require "test_helper"

class PushConfigTest < Minitest::Test
  def setup
    @vm_repo = Minitest::Mock.new
    @ct_repo = Minitest::Mock.new
    @service = Pvectl::Services::PushConfig.new(
      vm_repository: @vm_repo,
      container_repository: @ct_repo
    )
  end

  # --- prepare (single manifest) ---

  def test_prepare_update_vm_detects_changes
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
        options:
          onboot: true
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
    current_config = { cores: 4, memory: 4096, onboot: 1 }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    assert_equal 1, result[:plans].length
    plan = result[:plans].first
    assert_equal :update, plan[:action]
    assert_equal 100, plan[:vmid]
    assert_equal "pve1", plan[:node]
    assert plan[:diff][:changed].key?(:cores)
    assert plan[:params].key?(:cores)
    @vm_repo.verify
  end

  def test_prepare_create_vm_when_not_found
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    assert_equal 1, result[:plans].length
    plan = result[:plans].first
    assert_equal :create, plan[:action]
    assert_equal 999, plan[:vmid]
    assert_equal "pve1", plan[:node]
    assert plan[:params].key?(:cores)
    @vm_repo.verify
  end

  def test_prepare_create_without_node_errors
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    assert result[:errors].any? { |e| e.include?("Node is required") }
    @vm_repo.verify
  end

  def test_prepare_no_changes
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { cores: 4 }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    assert_empty result[:errors]
    assert result[:no_changes]
    @vm_repo.verify
  end

  def test_prepare_invalid_manifest
    yaml = "not: valid: yaml: {{"

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    refute_empty result[:errors]
  end

  def test_prepare_missing_api_version
    yaml = <<~YAML
      kind: VirtualMachine
      metadata:
        vmid: 100
    YAML

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    assert result[:errors].any? { |e| e.include?("apiVersion") }
  end

  def test_prepare_container_update
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Container
      metadata:
        vmid: 200
        node: pve1
      spec:
        resources:
          cpu:
            cores: 4
    YAML

    ct = Pvectl::Models::Container.new(vmid: 200, name: "test", hostname: "test", node: "pve1", status: "running")
    current_config = { cores: 2 }

    @ct_repo.expect :get, ct, [200]
    @ct_repo.expect :fetch_config, current_config, ["pve1", 200]

    result = @service.prepare(yaml)

    assert_equal 1, result[:plans].length
    assert_equal :update, result[:plans].first[:action]
    @ct_repo.verify
  end

  def test_prepare_update_includes_digest
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
    current_config = { cores: 4, digest: "abc123" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "abc123", plan[:params][:digest]
    @vm_repo.verify
  end

  # --- prepare_batch ---

  def test_prepare_batch_multiple_manifests
    yaml1 = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
    YAML
    yaml2 = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 101
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    vm2 = Pvectl::Models::Vm.new(vmid: 101, name: "vm2", node: "pve1", status: "running")
    config1 = { cores: 4 }
    config2 = { cores: 2 }

    @vm_repo.expect :get, vm1, [100]
    @vm_repo.expect :fetch_config, config1, ["pve1", 100]
    @vm_repo.expect :get, vm2, [101]
    @vm_repo.expect :fetch_config, config2, ["pve1", 101]

    yamls = [
      { filename: "vm-100.yaml", content: yaml1 },
      { filename: "vm-101.yaml", content: yaml2 }
    ]

    result = @service.prepare_batch(yamls)

    assert_equal 2, result[:plans].length
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_prepare_batch_skips_invalid
    valid_yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    config = { cores: 4 }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, config, ["pve1", 100]

    yamls = [
      { filename: "vm-100.yaml", content: valid_yaml },
      { filename: "bad.yaml", content: "invalid: yaml: {{" }
    ]

    result = @service.prepare_batch(yamls)

    assert_equal 1, result[:plans].length
    assert_equal 1, result[:errors].length
    assert result[:errors].first.start_with?("bad.yaml:")
    @vm_repo.verify
  end

  def test_prepare_batch_filters_by_kind
    vm_yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 8
    YAML
    ct_yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Container
      metadata:
        vmid: 200
        node: pve1
      spec:
        resources:
          cpu:
            cores: 2
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "vm1", node: "pve1", status: "running")
    config = { cores: 4 }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, config, ["pve1", 100]

    yamls = [
      { filename: "vm-100.yaml", content: vm_yaml },
      { filename: "ct-200.yaml", content: ct_yaml }
    ]

    result = @service.prepare_batch(yamls, filter_type: :vm)

    assert_equal 1, result[:plans].length
    assert_equal 100, result[:plans].first[:vmid]
    assert_equal 1, result[:skipped].length
    @vm_repo.verify
  end

  def test_prepare_batch_reports_no_changes
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { cores: 4 }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    yamls = [{ filename: "vm-100.yaml", content: yaml }]

    result = @service.prepare_batch(yamls)

    assert_empty result[:plans]
    assert_empty result[:errors]
    assert_equal 1, result[:skipped].length
    assert result[:skipped].first.include?("no changes")
    @vm_repo.verify
  end

  # --- apply ---

  def test_apply_update
    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { cores: 8, digest: "abc123" }
    }

    @vm_repo.expect :update, nil, [100, "pve1", { cores: 8, digest: "abc123" }]

    result = @service.apply([plan])

    assert_equal 1, result[:results].length
    assert result[:results].first[:success]
    assert_equal :vm, result[:results].first[:type]
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_apply_create
    plan = {
      action: :create,
      type: :vm,
      vmid: 999,
      node: "pve1",
      params: { cores: 4, memory: 4096 }
    }

    @vm_repo.expect :create, nil, ["pve1", 999, { cores: 4, memory: 4096 }]

    result = @service.apply([plan])

    assert_equal 1, result[:results].length
    assert result[:results].first[:success]
    assert_equal :vm, result[:results].first[:type]
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_apply_returns_correct_type_for_container
    plan = {
      action: :update,
      type: :container,
      vmid: 200,
      node: "pve1",
      params: { hostname: "web" }
    }

    @ct_repo.expect :update, nil, [200, "pve1", { hostname: "web" }]

    result = @service.apply([plan])

    assert_equal :container, result[:results].first[:type]
    @ct_repo.verify
  end

  # --- auto-VMID allocation ---

  def test_prepare_auto_allocates_vmid_when_missing
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    @vm_repo.expect :next_available_vmid, 500

    result = @service.prepare(yaml)

    assert_equal 1, result[:plans].length
    plan = result[:plans].first
    assert_equal :create, plan[:action]
    assert_equal 500, plan[:vmid]
    assert_equal "pve1", plan[:node]
    assert plan[:auto_id]
    @vm_repo.verify
  end

  def test_prepare_auto_allocates_ctid_for_container
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Container
      metadata:
        node: pve1
      spec:
        resources:
          cpu:
            cores: 2
    YAML

    @ct_repo.expect :next_available_ctid, 300

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :create, plan[:action]
    assert_equal 300, plan[:vmid]
    assert plan[:auto_id]
    @ct_repo.verify
  end

  def test_prepare_auto_vmid_requires_node
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        name: web
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    assert result[:errors].any? { |e| e.include?("Node is required") }
  end

  def test_apply_create_returns_auto_id_flag
    plan = {
      action: :create,
      type: :vm,
      vmid: 500,
      node: "pve1",
      params: { cores: 4 },
      auto_id: true,
      source_path: "/tmp/vm-new.yaml"
    }

    @vm_repo.expect :create, nil, ["pve1", 500, { cores: 4 }]

    result = @service.apply([plan])

    r = result[:results].first
    assert r[:success]
    assert r[:auto_id]
    assert_equal "/tmp/vm-new.yaml", r[:source_path]
    @vm_repo.verify
  end

  def test_apply_handles_api_error
    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { cores: 8 }
    }

    @vm_repo.expect(:update, nil) { raise StandardError, "API error: permission denied" }

    result = @service.apply([plan])

    assert_equal 1, result[:results].length
    refute result[:results].first[:success]
    assert_equal :vm, result[:results].first[:type]
    assert_equal 1, result[:errors].length
  end
end
