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
end
