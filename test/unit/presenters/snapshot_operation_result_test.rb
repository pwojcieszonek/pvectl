# frozen_string_literal: true

require "test_helper"

class SnapshotOperationResultPresenterTest < Minitest::Test
  def setup
    @presenter = Pvectl::Presenters::SnapshotOperationResult.new
  end

  def test_columns_returns_expected_headers
    expected = %w[VMID NAME TYPE NODE STATUS MESSAGE]
    assert_equal expected, @presenter.columns
  end

  def test_extra_columns_returns_expected_headers
    expected = %w[TASK DURATION]
    assert_equal expected, @presenter.extra_columns
  end

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[VMID NAME TYPE NODE STATUS MESSAGE TASK DURATION]
    assert_equal expected, @presenter.wide_columns
  end

  def test_to_row_returns_values_from_resource_hash
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web-server", type: :qemu, node: "pve1" },
      operation: :create,
      success: true
    )

    row = @presenter.to_row(result)

    assert_equal "100", row[0]
    assert_equal "web-server", row[1]
    assert_equal "qemu", row[2]
    assert_equal "pve1", row[3]
    assert_includes row[4], "Success"
    assert_equal "Success", row[5]
  end

  def test_to_row_handles_missing_resource_values
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 200 },
      operation: :create,
      success: true
    )

    row = @presenter.to_row(result)

    assert_equal "200", row[0]
    assert_equal "-", row[1]  # name
    assert_equal "-", row[2]  # type
    assert_equal "-", row[3]  # node
  end

  def test_to_row_handles_nil_resource
    result = Pvectl::Models::OperationResult.new(
      resource: nil,
      operation: :create,
      success: false,
      error: "Not found"
    )

    row = @presenter.to_row(result)

    assert_equal "", row[0]
    assert_equal "-", row[1]
    assert_equal "-", row[2]
    assert_equal "-", row[3]
  end

  def test_to_row_shows_failed_status
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web", type: :qemu, node: "pve1" },
      operation: :create,
      success: false,
      error: "Permission denied"
    )

    row = @presenter.to_row(result)

    assert_includes row[4], "Failed"
    assert_equal "Permission denied", row[5]
  end

  def test_to_row_shows_pending_status
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web", type: :qemu, node: "pve1" },
      operation: :create,
      success: :pending,
      task_upid: "UPID:pve1:00001234:..."
    )

    row = @presenter.to_row(result)

    assert_includes row[4], "Pending"
    assert_includes row[5], "UPID:pve1:00001234:..."
  end

  def test_to_hash_returns_all_fields
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web-server", type: :qemu, node: "pve1" },
      operation: :create,
      success: true,
      task_upid: "UPID:pve1:00001234:..."
    )

    hash = @presenter.to_hash(result)

    assert_equal 100, hash["vmid"]
    assert_equal "web-server", hash["name"]
    assert_equal "qemu", hash["type"]
    assert_equal "pve1", hash["node"]
    assert_equal "create", hash["operation"]
    assert_equal "Success", hash["status"]
    assert_equal "UPID:pve1:00001234:...", hash["task_upid"]
  end

  def test_to_hash_handles_nil_resource
    result = Pvectl::Models::OperationResult.new(
      resource: nil,
      operation: :create,
      success: false,
      error: "Not found"
    )

    hash = @presenter.to_hash(result)

    assert_nil hash["vmid"]
    assert_nil hash["name"]
    assert_nil hash["type"]
    assert_nil hash["node"]
    assert_equal "Not found", hash["message"]
  end

  def test_extra_values_returns_task_and_duration
    task = Pvectl::Models::Task.new(
      upid: "UPID:pve1:00001234:...",
      status: "stopped",
      exitstatus: "OK",
      starttime: 1_700_000_000,
      endtime: 1_700_000_005
    )

    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web", type: :qemu, node: "pve1" },
      operation: :create,
      success: true,
      task: task
    )

    values = @presenter.extra_values(result)

    assert_equal "UPID:pve1:00001234:...", values[0]
    assert_equal "5.0s", values[1]
  end

  def test_extra_values_shows_dash_without_task
    result = Pvectl::Models::OperationResult.new(
      resource: { vmid: 100, name: "web", type: :qemu, node: "pve1" },
      operation: :create,
      success: :pending,
      task_upid: "UPID:pve1:00001234:..."
    )

    values = @presenter.extra_values(result)

    assert_equal "UPID:pve1:00001234:...", values[0]
    assert_equal "-", values[1]
  end
end
