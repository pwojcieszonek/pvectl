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
    assert_equal 100, result[:vmid]
    assert_equal :vm, result[:type]
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

  def test_prepare_batch_returns_unchanged_with_metadata
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

    yamls = [{ filename: "vm-100.yaml", content: yaml, path: "/tmp/vm-100.yaml" }]

    result = @service.prepare_batch(yamls)

    assert_empty result[:plans]
    assert_equal 1, result[:unchanged].length
    entry = result[:unchanged].first
    assert_equal 100, entry[:vmid]
    assert_equal :vm, entry[:type]
    assert_equal "/tmp/vm-100.yaml", entry[:source_path]
    @vm_repo.verify
  end

  def test_prepare_batch_unchanged_without_path
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

    yamls = [{ filename: "stdin", content: yaml }]

    result = @service.prepare_batch(yamls)

    assert_equal 1, result[:unchanged].length
    assert_nil result[:unchanged].first[:source_path]
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

  def test_prepare_update_strips_readonly_from_both_sides
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
    # API returns digest — a readonly key that changes with every modification
    current_config = { cores: 4, digest: "abc123" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    # digest should NOT appear anywhere in the diff
    refute plan[:diff][:changed].key?(:digest), "digest should not appear in changed"
    refute plan[:diff][:added].key?(:digest), "digest should not appear in added"
    refute plan[:diff][:removed].include?(:digest), "digest should not appear in removed"
    # Real change (cores) should still be detected
    assert plan[:diff][:changed].key?(:cores)
    @vm_repo.verify
  end

  def test_prepare_update_strips_digest_from_manifest
    # Simulates manifest from pull that includes digest in general section
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        general:
          digest: stale_digest_from_pull
        hardware:
          cpu:
            cores: 8
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
    current_config = { cores: 4, digest: "current_api_digest" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    refute plan[:diff][:changed].key?(:digest), "stale digest from manifest should be stripped"
    refute plan[:diff][:added].key?(:digest), "stale digest should not appear as added"
    assert plan[:diff][:changed].key?(:cores)
    @vm_repo.verify
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

  # --- disk resize detection ---

  def test_prepare_detects_disk_resize
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              volume: vm-100-disk-0
              size: 9G
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { scsi0: "local-lvm:vm-100-disk-0,size=8G" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    assert plan[:resize_ops].any? { |op| op[:disk] == "scsi0" && op[:size] == "9G" }
    # scsi0 should not be in config params (only size changed)
    refute plan[:params].key?(:scsi0)
    @vm_repo.verify
  end

  def test_prepare_disk_resize_with_other_changes
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              volume: vm-100-disk-0
              size: 9G
              iothread: true
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { scsi0: "local-lvm:vm-100-disk-0,size=8G,iothread=0" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    # Resize should be extracted
    assert plan[:resize_ops].any? { |op| op[:disk] == "scsi0" && op[:size] == "9G" }
    # Config params should have scsi0 with OLD size (for other option changes)
    assert plan[:params].key?(:scsi0)
    assert_includes plan[:params][:scsi0], "size=8G"
    assert_includes plan[:params][:scsi0], "iothread=1"
    @vm_repo.verify
  end

  def test_apply_calls_resize_for_disk_changes
    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { digest: "abc123" },
      resize_ops: [{ disk: "scsi0", size: "9G" }]
    }

    @vm_repo.expect :resize, nil, [100, "pve1"], disk: "scsi0", size: "9G"

    result = @service.apply([plan])

    assert_equal 1, result[:results].length
    assert result[:results].first[:success]
    @vm_repo.verify
  end

  def test_apply_update_with_config_and_resize
    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { cores: 8, digest: "abc123" },
      resize_ops: [{ disk: "scsi0", size: "9G" }]
    }

    @vm_repo.expect :update, nil, [100, "pve1", { cores: 8, digest: "abc123" }]
    @vm_repo.expect :resize, nil, [100, "pve1"], disk: "scsi0", size: "9G"

    result = @service.apply([plan])

    assert result[:results].first[:success]
    @vm_repo.verify
  end

  def test_prepare_no_resize_when_disk_size_unchanged
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              volume: vm-100-disk-0
              size: 8G
              iothread: true
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { scsi0: "local-lvm:vm-100-disk-0,size=8G,iothread=0" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    # No resize ops — only iothread changed
    assert_empty plan[:resize_ops]
    # scsi0 should be in config params (non-size change)
    assert plan[:params].key?(:scsi0)
    @vm_repo.verify
  end

  # --- async task tracking ---

  def test_apply_resize_reports_failure_when_task_fails
    task_repo = Object.new
    failed_task = Pvectl::Models::Task.new(
      upid: "UPID:pve1:000:00:00:qmresize:100:root@pam:",
      node: "pve1", type: "qmresize", status: "stopped",
      exitstatus: "can't lock file - got timeout",
      starttime: Time.now.to_i, user: "root@pam"
    )
    task_repo.define_singleton_method(:wait) { |_upid, **_kwargs| failed_task }

    service = Pvectl::Services::PushConfig.new(
      vm_repository: @vm_repo,
      container_repository: @ct_repo,
      task_repository: task_repo
    )

    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { digest: "abc123" },
      resize_ops: [{ disk: "scsi0", size: "9G" }]
    }

    @vm_repo.expect :resize, "UPID:pve1:000:00:00:qmresize:100:root@pam:", [100, "pve1"], disk: "scsi0", size: "9G"

    result = service.apply([plan])

    refute result[:results].first[:success]
    assert_equal 1, result[:errors].length
    assert result[:errors].first.include?("lock file")
    @vm_repo.verify
  end

  def test_apply_resize_reports_success_when_task_succeeds
    task_repo = Object.new
    ok_task = Pvectl::Models::Task.new(
      upid: "UPID:pve1:000:00:00:qmresize:100:root@pam:",
      node: "pve1", type: "qmresize", status: "stopped",
      exitstatus: "OK",
      starttime: Time.now.to_i, user: "root@pam"
    )
    task_repo.define_singleton_method(:wait) { |_upid, **_kwargs| ok_task }

    service = Pvectl::Services::PushConfig.new(
      vm_repository: @vm_repo,
      container_repository: @ct_repo,
      task_repository: task_repo
    )

    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { digest: "abc123" },
      resize_ops: [{ disk: "scsi0", size: "9G" }]
    }

    @vm_repo.expect :resize, "UPID:pve1:000:00:00:qmresize:100:root@pam:", [100, "pve1"], disk: "scsi0", size: "9G"

    result = service.apply([plan])

    assert result[:results].first[:success]
    assert_empty result[:errors]
    @vm_repo.verify
  end

  def test_apply_create_reports_failure_when_task_fails
    task_repo = Object.new
    failed_task = Pvectl::Models::Task.new(
      upid: "UPID:pve2:000:00:00:qmcreate:999:root@pam:",
      node: "pve2", type: "qmcreate", status: "stopped",
      exitstatus: "No space left on device",
      starttime: Time.now.to_i, user: "root@pam"
    )
    task_repo.define_singleton_method(:wait) { |_upid, **_kwargs| failed_task }

    service = Pvectl::Services::PushConfig.new(
      vm_repository: @vm_repo,
      container_repository: @ct_repo,
      task_repository: task_repo
    )

    plan = {
      action: :create,
      type: :vm,
      vmid: 999,
      node: "pve1",
      params: { cores: 4 }
    }

    @vm_repo.expect :create, "UPID:pve2:000:00:00:qmcreate:999:root@pam:", ["pve1", 999, { cores: 4 }]

    result = service.apply([plan])

    refute result[:results].first[:success]
    assert_equal 1, result[:errors].length
    assert result[:errors].first.include?("No space left")
    @vm_repo.verify
  end

  def test_apply_without_task_repo_still_reports_success
    # Backward compatibility: when task_repository is nil, fire-and-forget
    plan = {
      action: :update,
      type: :vm,
      vmid: 100,
      node: "pve1",
      params: { digest: "abc123" },
      resize_ops: [{ disk: "scsi0", size: "9G" }]
    }

    @vm_repo.expect :resize, "UPID:pve1:000:resize:100", [100, "pve1"], disk: "scsi0", size: "9G"

    result = @service.apply([plan])

    # Without task_repo, we can't verify — reports success (fire-and-forget)
    assert result[:results].first[:success]
    @vm_repo.verify
  end

  # --- update: omitted values should not generate diffs ---

  def test_prepare_update_ignores_api_only_keys
    # Manifest specifies only cores; API also has memory and smbios1.
    # Keys only in API should NOT appear in the diff.
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

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { cores: 4, memory: 2048, smbios1: "uuid=abc-123" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    assert plan[:diff][:changed].key?(:cores)
    # memory and smbios1 are API-only — should not be in diff
    refute plan[:diff][:removed].include?(:memory), "API-only memory should not appear as removed"
    refute plan[:diff][:removed].include?(:smbios1), "API-only smbios1 should not appear as removed"
    @vm_repo.verify
  end

  def test_prepare_update_completes_disk_from_api
    # Manifest has disk without volume — should be completed from API, no false diff
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              iothread: true
              size: 9G
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { scsi0: "local-lvm:vm-100-disk-0,iothread=1,size=9G" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    # Volume filled from API → no diff
    assert_empty result[:plans]
    assert result[:no_changes]
    @vm_repo.verify
  end

  def test_prepare_update_completes_net_from_api
    # Manifest has net without mac — should be completed from API, no false diff
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          network:
            net0:
              model: virtio
              bridge: vmbr0
              firewall: true
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { net0: "virtio=BC:24:11:16:54:F1,bridge=vmbr0,firewall=1" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    assert_empty result[:plans]
    assert result[:no_changes]
    @vm_repo.verify
  end

  def test_prepare_update_filters_nil_manifest_values
    # Manifest has smbios1: null — should be ignored, not treated as removal
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
        options:
          smbios1:
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { cores: 4, smbios1: "uuid=abc-123" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    # nil smbios1 filtered + cores unchanged = no changes
    assert_empty result[:plans]
    assert result[:no_changes]
    @vm_repo.verify
  end

  def test_prepare_update_detects_real_changes_with_completed_values
    # Manifest changes bridge but omits MAC — should detect bridge change only
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        node: pve1
      spec:
        hardware:
          network:
            net0:
              model: virtio
              bridge: vmbr1
              firewall: true
    YAML

    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
    current_config = { net0: "virtio=BC:24:11:16:54:F1,bridge=vmbr0,firewall=1" }

    @vm_repo.expect :get, vm, [100]
    @vm_repo.expect :fetch_config, current_config, ["pve1", 100]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :update, plan[:action]
    assert plan[:diff][:changed].key?(:net0)
    # New value should include MAC (filled from API) and new bridge
    new_val = plan[:diff][:changed][:net0][1]
    assert_includes new_val, "BC:24:11:16:54:F1"
    assert_includes new_val, "bridge=vmbr1"
    @vm_repo.verify
  end

  # --- disk value transformation for create ---

  def test_prepare_create_transforms_disk_with_volume_name
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              volume: vm-100-disk-0
              size: 8G
              iothread: true
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :create, plan[:action]
    # Disk should be in create format: storage:size_gib,options
    assert_equal "local-lvm:8,iothread=1", plan[:params][:scsi0]
    @vm_repo.verify
  end

  def test_prepare_create_transforms_disk_without_volume
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              iothread: true
              size: 9G
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "local-lvm:9,iothread=1", plan[:params][:scsi0]
    @vm_repo.verify
  end

  def test_prepare_create_preserves_empty_cdrom
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 2
          disks:
            ide2:
              storage: none
              media: cdrom
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "none,media=cdrom", plan[:params][:ide2]
    @vm_repo.verify
  end

  def test_prepare_create_transforms_cloudinit_disk
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 2
          disks:
            ide0:
              storage: local-lvm
              volume: vm-100-cloudinit
              media: cdrom
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "local-lvm:cloudinit", plan[:params][:ide0]
    @vm_repo.verify
  end

  def test_prepare_create_transforms_efidisk_without_size
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 2
          disks:
            efidisk0:
              storage: local-lvm
              volume: vm-100-disk-1
              efitype: 4m
              "pre-enrolled-keys": "1"
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    # EFI disk has no size= — should use default "1"
    assert_equal "local-lvm:1,efitype=4m,pre-enrolled-keys=1", plan[:params][:efidisk0]
    @vm_repo.verify
  end

  def test_prepare_create_transforms_container_rootfs
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Container
      metadata:
        vmid: 999
        node: pve1
      spec:
        resources:
          rootfs:
            rootfs:
              storage: local-lvm
              volume: subvol-100-disk-0
              size: 4G
    YAML

    @ct_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :create, plan[:action]
    assert_equal "local-lvm:4", plan[:params][:rootfs]
    @ct_repo.verify
  end

  def test_prepare_create_preserves_non_disk_params
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
          memory:
            memory: 8192
          disks:
            scsi0:
              storage: local-lvm
              size: 32G
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    # Non-disk params should be unchanged
    assert_equal 4, plan[:params][:cores]
    assert_equal 8192, plan[:params][:memory]
    # Disk should be transformed
    assert_equal "local-lvm:32", plan[:params][:scsi0]
    @vm_repo.verify
  end

  def test_prepare_create_size_conversion_terabytes
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          disks:
            scsi0:
              storage: local-lvm
              size: 2T
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "local-lvm:2048", plan[:params][:scsi0]
    @vm_repo.verify
  end

  def test_prepare_create_filters_nil_values
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
        options:
          smbios1:
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal :create, plan[:action]
    # nil smbios1 should be filtered out
    refute plan[:params].key?(:smbios1), "nil values should be filtered from create params"
    assert_equal 4, plan[:params][:cores]
    @vm_repo.verify
  end

  def test_prepare_create_filters_empty_string_values
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
        options:
          smbios1: {}
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    # Empty smbios1 (serialized to empty string) should be filtered
    refute plan[:params].key?(:smbios1), "empty string values should be filtered from create params"
    @vm_repo.verify
  end

  def test_prepare_create_transforms_cloudinit_without_volume
    # User writes manifest with storage + media=cdrom but no volume
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 2
          disks:
            ide0:
              storage: local-lvm
              media: cdrom
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    # No volume + media=cdrom on real storage → cloud-init
    assert_equal "local-lvm:cloudinit", plan[:params][:ide0]
    @vm_repo.verify
  end

  def test_prepare_create_transforms_cloudinit_with_normalized_volume
    # Simulates manifest from pull where cloud-init volume is normalized to "cloudinit"
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 999
        node: pve1
      spec:
        hardware:
          cpu:
            cores: 2
          disks:
            ide0:
              storage: local-lvm
              volume: cloudinit
              media: cdrom
    YAML

    @vm_repo.expect :get, nil, [999]

    result = @service.prepare(yaml)

    plan = result[:plans].first
    assert_equal "local-lvm:cloudinit", plan[:params][:ide0]
    @vm_repo.verify
  end

  def test_apply_reports_detailed_api_error
    # Simulate ProxmoxAPI::ApiException with JSON error body
    api_response = Minitest::Mock.new
    api_response.expect :body, '{"errors":{"ide0":"value does not look like a valid disk volume"}}'
    api_exception = ProxmoxAPI::ApiException.new(api_response, "Proxmox API request failed")

    @vm_repo.expect(:create, nil) { raise api_exception }

    plan = {
      action: :create,
      type: :vm,
      vmid: 999,
      node: "pve1",
      params: { cores: 4 }
    }

    result = @service.apply([plan])

    refute result[:results].first[:success]
    assert result[:errors].first.include?("ide0"), "should include field-level error detail"
    assert result[:errors].first.include?("valid disk volume"), "should include Proxmox error message"
  end
end
