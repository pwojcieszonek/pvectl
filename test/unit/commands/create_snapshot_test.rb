# frozen_string_literal: true

require "test_helper"

class CreateSnapshotTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    $stderr = StringIO.new
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_no_snapshot_name
    exit_code = Pvectl::Commands::CreateSnapshot.execute([], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_missing_snapshot_name
    Pvectl::Commands::CreateSnapshot.execute([], {}, {})
    assert_includes $stderr.string, "Snapshot name required"
  end

  def test_parses_snapshot_name_from_first_arg
    cmd = Pvectl::Commands::CreateSnapshot.new(["before-upgrade"], {}, {})
    assert_equal "before-upgrade", cmd.instance_variable_get(:@snapshot_name)
  end

  def test_parses_vmids_from_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})
    assert_equal [100, 101], cmd.instance_variable_get(:@vmids)
  end

  def test_vmids_empty_when_no_vmid_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], {}, {})
    assert_equal [], cmd.instance_variable_get(:@vmids)
  end

  def test_parses_node_from_option
    cmd = Pvectl::Commands::CreateSnapshot.new(["snap1"], { node: "pve1" }, {})
    assert_equal "pve1", cmd.instance_variable_get(:@node)
  end

  def test_validates_vmid_is_numeric
    Pvectl::Commands::CreateSnapshot.execute(["snap1"], { vmid: ["abc"] }, {})
    assert_includes $stderr.string, "Invalid VMID"
  end

  def test_returns_usage_error_for_invalid_vmid
    exit_code = Pvectl::Commands::CreateSnapshot.execute(["snap1"], { vmid: ["abc"] }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end
end

class CreateSnapshotConfirmationTest < Minitest::Test
  class TestableCreateSnapshot < Pvectl::Commands::CreateSnapshot
    def test_confirm_operation
      confirm_operation
    end
  end

  def setup
    @original_stdin = $stdin
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stdin = @original_stdin
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def test_skips_confirmation_for_single_vmid
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100"] }, {})
    result = cmd.test_confirm_operation
    assert result, "Single VMID should not require confirmation"
  end

  def test_skips_confirmation_with_yes_flag
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"], yes: true }, {})
    result = cmd.test_confirm_operation
    assert result, "--yes flag should skip confirmation"
  end

  def test_confirms_multi_vmid_operation_with_y_response
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})

    $stdin = StringIO.new("y\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    assert result, "Should proceed with 'y' response"
  end

  def test_aborts_multi_vmid_operation_with_n_response
    cmd = TestableCreateSnapshot.new(["snap1"], { vmid: ["100", "101"] }, {})

    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    refute result, "Should abort with 'n' response"
  end

  def test_cluster_wide_confirmation_prompt
    cmd = TestableCreateSnapshot.new(["before-upgrade"], {}, {})

    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd.test_confirm_operation
    output_str = output.string

    assert_includes output_str, "You are about to create snapshot"
    assert_includes output_str, "before-upgrade"
    assert_includes output_str, "ALL VMs/CTs"
    assert_includes output_str, "Proceed? [y/N]:"
  end

  def test_multi_vmid_confirmation_prompt
    cmd = TestableCreateSnapshot.new(["before-upgrade"], { vmid: ["100", "101", "102"] }, {})

    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd.test_confirm_operation
    output_str = output.string

    assert_includes output_str, "You are about to create snapshot"
    assert_includes output_str, "before-upgrade"
    assert_includes output_str, "3 VMs"
    assert_includes output_str, "100"
    assert_includes output_str, "101"
    assert_includes output_str, "102"
  end
end
