# frozen_string_literal: true

require "test_helper"

class TaskEntryModelTest < Minitest::Test
  def setup
    @entry = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:000ABC:001234:65B63BF0:qmstart:100:root@pam:",
      node: "pve1", type: "qmstart", status: "stopped", exitstatus: "OK",
      starttime: 1_708_300_000, endtime: 1_708_300_005, user: "root@pam",
      id: "100", pid: 2748, pstart: 74292
    )
  end

  def test_attributes
    assert_equal "pve1", @entry.node
    assert_equal "qmstart", @entry.type
    assert_equal "root@pam", @entry.user
    assert_equal "100", @entry.id
  end

  def test_successful
    assert @entry.successful?
  end

  def test_failed
    failed = Pvectl::Models::TaskEntry.new(status: "stopped", exitstatus: "command failed")
    assert failed.failed?
    refute failed.successful?
  end

  def test_completed
    assert @entry.completed?
    running = Pvectl::Models::TaskEntry.new(status: "running")
    refute running.completed?
  end

  def test_duration
    assert_equal 5, @entry.duration
  end

  def test_duration_nil_when_endtime_missing
    entry = Pvectl::Models::TaskEntry.new(starttime: 1_708_300_000, endtime: nil)
    assert_nil entry.duration
  end
end
