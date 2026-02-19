# frozen_string_literal: true

require "test_helper"

class ModelsContainerOperationResultTest < Minitest::Test
  def setup
    @container = Pvectl::Models::Container.new(vmid: 200, name: "test-ct", node: "pve1", status: "running")
    @task_success = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK")
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Models::ContainerOperationResult
  end

  def test_inherits_from_operation_result
    assert Pvectl::Models::ContainerOperationResult < Pvectl::Models::OperationResult
  end

  def test_has_container_attribute
    result = Pvectl::Models::ContainerOperationResult.new(container: @container)
    assert_equal @container, result.container
  end

  def test_inherits_successful_check
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, success: true)
    assert result.successful?
  end

  def test_inherits_failed_check
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, success: false)
    assert result.failed?
  end

  def test_inherits_pending_check
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, success: :pending)
    assert result.pending?
  end

  def test_inherits_message
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, error: "Permission denied")
    assert_equal "Permission denied", result.message
  end

  def test_inherits_status_text
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, success: true)
    assert_equal "Success", result.status_text
  end

  def test_has_operation_attribute
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, operation: :start)
    assert_equal :start, result.operation
  end

  def test_has_task_attribute
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, task: @task_success)
    assert_equal @task_success, result.task
  end

  def test_has_task_upid_attribute
    result = Pvectl::Models::ContainerOperationResult.new(container: @container, task_upid: "UPID:pve1:...")
    assert_equal "UPID:pve1:...", result.task_upid
  end
end
