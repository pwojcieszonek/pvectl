# frozen_string_literal: true

require "test_helper"

class ModelsTaskTest < Minitest::Test
  def test_task_class_exists
    assert_kind_of Class, Pvectl::Models::Task
  end

  def test_task_inherits_from_base
    assert Pvectl::Models::Task < Pvectl::Models::Base
  end

  def test_task_has_upid_attribute
    task = Pvectl::Models::Task.new(upid: "UPID:pve1:000ABC:123:456:qmstart:100:root@pam:")
    assert_equal "UPID:pve1:000ABC:123:456:qmstart:100:root@pam:", task.upid
  end

  def test_task_has_node_attribute
    task = Pvectl::Models::Task.new(node: "pve1")
    assert_equal "pve1", task.node
  end

  def test_task_has_type_attribute
    task = Pvectl::Models::Task.new(type: "qmstart")
    assert_equal "qmstart", task.type
  end

  def test_task_has_status_attribute
    task = Pvectl::Models::Task.new(status: "running")
    assert_equal "running", task.status
  end

  def test_task_has_exitstatus_attribute
    task = Pvectl::Models::Task.new(exitstatus: "OK")
    assert_equal "OK", task.exitstatus
  end

  def test_task_has_starttime_attribute
    task = Pvectl::Models::Task.new(starttime: 1707000000)
    assert_equal 1707000000, task.starttime
  end

  def test_task_has_endtime_attribute
    task = Pvectl::Models::Task.new(endtime: 1707000060)
    assert_equal 1707000060, task.endtime
  end

  def test_task_has_user_attribute
    task = Pvectl::Models::Task.new(user: "root@pam")
    assert_equal "root@pam", task.user
  end

  # Predicates
  def test_pending_returns_true_when_status_is_running
    task = Pvectl::Models::Task.new(status: "running")
    assert task.pending?
  end

  def test_pending_returns_false_when_status_is_stopped
    task = Pvectl::Models::Task.new(status: "stopped")
    refute task.pending?
  end

  def test_completed_returns_true_when_status_is_stopped
    task = Pvectl::Models::Task.new(status: "stopped")
    assert task.completed?
  end

  def test_completed_returns_false_when_status_is_running
    task = Pvectl::Models::Task.new(status: "running")
    refute task.completed?
  end

  def test_successful_returns_true_when_completed_with_ok_exitstatus
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK")
    assert task.successful?
  end

  def test_successful_returns_false_when_still_running
    task = Pvectl::Models::Task.new(status: "running", exitstatus: nil)
    refute task.successful?
  end

  def test_successful_returns_false_when_exitstatus_is_error
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "ERROR")
    refute task.successful?
  end

  def test_failed_returns_true_when_completed_with_non_ok_exitstatus
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "ERROR")
    assert task.failed?
  end

  def test_failed_returns_false_when_successful
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK")
    refute task.failed?
  end

  def test_failed_returns_false_when_still_running
    task = Pvectl::Models::Task.new(status: "running")
    refute task.failed?
  end

  def test_duration_returns_difference_between_endtime_and_starttime
    task = Pvectl::Models::Task.new(starttime: 1707000000, endtime: 1707000045)
    assert_equal 45, task.duration
  end

  def test_duration_returns_nil_when_endtime_missing
    task = Pvectl::Models::Task.new(starttime: 1707000000, endtime: nil)
    assert_nil task.duration
  end

  def test_duration_returns_nil_when_starttime_missing
    task = Pvectl::Models::Task.new(starttime: nil, endtime: 1707000045)
    assert_nil task.duration
  end
end
