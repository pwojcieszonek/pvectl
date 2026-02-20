# frozen_string_literal: true

require "test_helper"

class PresentersVmOperationResultTest < Minitest::Test
  def setup
    @vm = Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", node: "pve1", status: "running")
    @task_success = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK", upid: "UPID:pve1:ABC")
    @presenter = Pvectl::Presenters::VmOperationResult.new
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Presenters::VmOperationResult
  end

  def test_inherits_from_operation_result
    assert Pvectl::Presenters::VmOperationResult < Pvectl::Presenters::OperationResult
  end

  def test_columns_returns_vm_columns
    expected = %w[VMID NAME NODE STATUS MESSAGE]
    assert_equal expected, @presenter.columns
  end

  def test_extra_columns_returns_wide_columns
    expected = %w[TASK DURATION]
    assert_equal expected, @presenter.extra_columns
  end

  def test_to_row_returns_array_of_values
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :start,
      success: true
    )

    row = @presenter.to_row(result)

    assert_kind_of Array, row
    assert_equal 5, row.length
    assert_equal "100", row[0]
    assert_equal "test-vm", row[1]
    assert_equal "pve1", row[2]
    assert_includes row[3], "Success"
    assert_equal "Success", row[4]
  end

  def test_to_row_shows_failed_status
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :stop,
      success: false,
      error: "Permission denied"
    )

    row = @presenter.to_row(result)

    assert_includes row[3], "Failed"
    assert_equal "Permission denied", row[4]
  end

  def test_to_row_shows_pending_status
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :shutdown,
      task_upid: "UPID:pve1:XYZ",
      success: :pending
    )

    row = @presenter.to_row(result)

    assert_includes row[3], "Pending"
    assert_equal "Task: UPID:pve1:XYZ", row[4]
  end

  def test_to_row_shows_vm_fallback_name
    vm_no_name = Pvectl::Models::Vm.new(vmid: 200, node: "pve1", status: "stopped")
    result = Pvectl::Models::VmOperationResult.new(vm: vm_no_name, success: true)

    row = @presenter.to_row(result)

    assert_equal "VM-200", row[1]
  end

  # --- Clone operation: displays new VM data ---

  def test_to_row_shows_new_vm_data_for_clone_operation
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :clone,
      success: true,
      resource: { new_vmid: 200, name: "test-clone", node: "pve2" }
    )

    row = @presenter.to_row(result)

    assert_equal "200", row[0]
    assert_equal "test-clone", row[1]
    assert_equal "pve2", row[2]
  end

  def test_to_row_clone_falls_back_to_source_node_when_resource_node_nil
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :clone,
      success: true,
      resource: { new_vmid: 200, name: "test-clone", node: nil }
    )

    row = @presenter.to_row(result)

    assert_equal "pve1", row[2]
  end

  def test_to_row_clone_falls_back_to_vm_name_format_when_name_nil
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :clone,
      success: true,
      resource: { new_vmid: 200, name: nil, node: "pve1" }
    )

    row = @presenter.to_row(result)

    assert_equal "VM-200", row[1]
  end

  def test_to_hash_shows_new_vm_data_for_clone_operation
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :clone,
      task: @task_success,
      success: true,
      resource: { new_vmid: 200, name: "test-clone", node: "pve2" }
    )

    hash = @presenter.to_hash(result)

    assert_equal 200, hash["vmid"]
    assert_equal "test-clone", hash["name"]
    assert_equal "pve2", hash["node"]
    assert_equal "Success", hash["status"]
    assert_equal "UPID:pve1:ABC", hash["task_upid"]
  end

  def test_to_row_shows_source_vm_for_non_clone_operations
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :start,
      success: true
    )

    row = @presenter.to_row(result)

    assert_equal "100", row[0]
    assert_equal "test-vm", row[1]
    assert_equal "pve1", row[2]
  end

  def test_extra_values_returns_task_and_duration
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      task: Pvectl::Models::Task.new(
        upid: "UPID:pve1:ABC",
        starttime: 1707000000,
        endtime: 1707000030,
        status: "stopped",
        exitstatus: "OK"
      )
    )

    extra = @presenter.extra_values(result)

    assert_equal 2, extra.length
    assert_equal "UPID:pve1:ABC", extra[0]
    assert_equal "30.0s", extra[1]
  end

  def test_extra_values_with_no_task_shows_dashes
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      success: true
    )

    extra = @presenter.extra_values(result)

    assert_equal "-", extra[0]
    assert_equal "-", extra[1]
  end

  def test_to_hash_returns_complete_hash
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm,
      operation: :start,
      task: @task_success,
      success: true
    )

    hash = @presenter.to_hash(result)

    assert_equal 100, hash["vmid"]
    assert_equal "test-vm", hash["name"]
    assert_equal "pve1", hash["node"]
    assert_equal "Success", hash["status"]
    assert_equal "OK", hash["message"]
    assert_equal "UPID:pve1:ABC", hash["task_upid"]
  end
end
