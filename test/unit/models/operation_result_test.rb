# frozen_string_literal: true

require "test_helper"

class ModelsOperationResultTest < Minitest::Test
  def setup
    @vm = Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", node: "pve1", status: "running")
    @task_success = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK")
    @task_failed = Pvectl::Models::Task.new(status: "stopped", exitstatus: "ERROR")
    @task_pending = Pvectl::Models::Task.new(status: "running")
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Models::OperationResult
  end

  def test_inherits_from_base
    assert Pvectl::Models::OperationResult < Pvectl::Models::Base
  end

  def test_has_resource_attribute
    resource = { vmid: 100, node: "pve1", type: :qemu, name: "web" }
    result = Pvectl::Models::OperationResult.new(resource: resource)
    assert_equal resource, result.resource
    assert_equal 100, result.resource[:vmid]
  end

  def test_has_operation_attribute
    result = Pvectl::Models::OperationResult.new(operation: :start)
    assert_equal :start, result.operation
  end

  def test_has_task_attribute
    result = Pvectl::Models::OperationResult.new(task: @task_success)
    assert_equal @task_success, result.task
  end

  def test_has_task_upid_attribute
    result = Pvectl::Models::OperationResult.new(task_upid: "UPID:pve1:...")
    assert_equal "UPID:pve1:...", result.task_upid
  end

  def test_has_success_attribute
    result = Pvectl::Models::OperationResult.new(success: true)
    assert_equal true, result.success
  end

  def test_has_error_attribute
    result = Pvectl::Models::OperationResult.new(error: "Permission denied")
    assert_equal "Permission denied", result.error
  end

  # successful?
  def test_successful_returns_true_when_success_is_true
    result = Pvectl::Models::OperationResult.new(success: true)
    assert result.successful?
  end

  def test_successful_returns_true_when_task_is_successful
    result = Pvectl::Models::OperationResult.new(task: @task_success)
    assert result.successful?
  end

  def test_successful_returns_false_when_success_is_false
    result = Pvectl::Models::OperationResult.new(success: false)
    refute result.successful?
  end

  def test_successful_returns_false_when_task_failed
    result = Pvectl::Models::OperationResult.new(task: @task_failed)
    refute result.successful?
  end

  # failed?
  def test_failed_returns_true_when_success_is_false
    result = Pvectl::Models::OperationResult.new(success: false)
    assert result.failed?
  end

  def test_failed_returns_true_when_task_failed
    result = Pvectl::Models::OperationResult.new(task: @task_failed)
    assert result.failed?
  end

  def test_failed_returns_false_when_successful
    result = Pvectl::Models::OperationResult.new(success: true)
    refute result.failed?
  end

  # pending?
  def test_pending_returns_true_when_success_is_pending_symbol
    result = Pvectl::Models::OperationResult.new(success: :pending)
    assert result.pending?
  end

  def test_pending_returns_true_when_task_is_pending
    result = Pvectl::Models::OperationResult.new(task: @task_pending)
    assert result.pending?
  end

  def test_pending_returns_false_when_completed
    result = Pvectl::Models::OperationResult.new(success: true)
    refute result.pending?
  end

  # status_text
  def test_status_text_returns_pending_when_pending
    result = Pvectl::Models::OperationResult.new(success: :pending)
    assert_equal "Pending", result.status_text
  end

  def test_status_text_returns_success_when_successful
    result = Pvectl::Models::OperationResult.new(success: true)
    assert_equal "Success", result.status_text
  end

  def test_status_text_returns_failed_when_failed
    result = Pvectl::Models::OperationResult.new(success: false)
    assert_equal "Failed", result.status_text
  end

  # message
  def test_message_returns_error_when_error_present
    result = Pvectl::Models::OperationResult.new(error: "Permission denied")
    assert_equal "Permission denied", result.message
  end

  def test_message_returns_task_exitstatus_when_task_present
    result = Pvectl::Models::OperationResult.new(task: @task_success)
    assert_equal "OK", result.message
  end

  def test_message_returns_task_upid_when_pending
    result = Pvectl::Models::OperationResult.new(task_upid: "UPID:pve1:ABC")
    assert_equal "Task: UPID:pve1:ABC", result.message
  end

  def test_message_returns_status_text_as_fallback
    result = Pvectl::Models::OperationResult.new(success: true)
    assert_equal "Success", result.message
  end
end
