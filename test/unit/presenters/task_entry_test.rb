# frozen_string_literal: true

require "test_helper"

class TaskEntryPresenterTest < Minitest::Test
  def setup
    @presenter = Pvectl::Presenters::TaskEntry.new
    @entry = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:000ABC:001234:65B63BF0:qmstart:100:root@pam:",
      node: "pve1", type: "qmstart", status: "stopped", exitstatus: "OK",
      starttime: 1_708_300_000, endtime: 1_708_300_005, user: "root@pam",
      id: "100", pid: 2748
    )
  end

  def test_columns
    assert_equal %w[STARTTIME TYPE STATUS USER DURATION NODE], @presenter.columns
  end

  def test_extra_columns
    assert_equal %w[UPID ENDTIME ID PID], @presenter.extra_columns
  end

  def test_to_row_returns_array_matching_columns
    row = @presenter.to_row(@entry)
    assert_equal 6, row.size
    assert_includes row, "qmstart"
    assert_includes row, "OK"
    assert_includes row, "root@pam"
    assert_includes row, "pve1"
  end

  def test_to_row_formats_duration
    row = @presenter.to_row(@entry)
    assert_includes row, "5s"
  end

  def test_to_row_nil_duration_shows_dash
    entry = Pvectl::Models::TaskEntry.new(
      type: "qmstart", status: "running", exitstatus: nil,
      starttime: 1_708_300_000, endtime: nil, user: "root@pam", node: "pve1"
    )
    row = @presenter.to_row(entry)
    assert_includes row, "-"
  end

  def test_to_hash
    hash = @presenter.to_hash(@entry)
    assert_equal "qmstart", hash["type"]
    assert_equal "OK", hash["exitstatus"]
    assert_equal "pve1", hash["node"]
    assert_equal "root@pam", hash["user"]
    assert_equal 5, hash["duration"]
  end
end
