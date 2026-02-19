# frozen_string_literal: true

require "test_helper"

class ModelsVmOperationResultTest < Minitest::Test
  def setup
    @vm = Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", node: "pve1", status: "running")
    @task_success = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK")
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Models::VmOperationResult
  end

  def test_inherits_from_operation_result
    assert Pvectl::Models::VmOperationResult < Pvectl::Models::OperationResult
  end

  def test_has_vm_attribute
    result = Pvectl::Models::VmOperationResult.new(vm: @vm)
    assert_equal @vm, result.vm
  end

  def test_inherits_successful_check
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, success: true)
    assert result.successful?
  end

  def test_inherits_failed_check
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, success: false)
    assert result.failed?
  end

  def test_inherits_pending_check
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, success: :pending)
    assert result.pending?
  end

  def test_inherits_message
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, error: "Permission denied")
    assert_equal "Permission denied", result.message
  end

  def test_inherits_status_text
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, success: true)
    assert_equal "Success", result.status_text
  end

  def test_has_operation_attribute
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, operation: :start)
    assert_equal :start, result.operation
  end

  def test_has_task_attribute
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, task: @task_success)
    assert_equal @task_success, result.task
  end

  def test_has_task_upid_attribute
    result = Pvectl::Models::VmOperationResult.new(vm: @vm, task_upid: "UPID:pve1:...")
    assert_equal "UPID:pve1:...", result.task_upid
  end
end
