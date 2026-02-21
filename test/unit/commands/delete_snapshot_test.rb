# frozen_string_literal: true

require "test_helper"

class DeleteSnapshotTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    @original_stdin = $stdin
    $stderr = StringIO.new
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    $stdin = @original_stdin
  end

  def test_returns_usage_error_when_no_name_and_no_all
    exit_code = Pvectl::Commands::DeleteSnapshot.execute([], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_missing_name_and_all
    Pvectl::Commands::DeleteSnapshot.execute([], {}, {})
    assert_includes $stderr.string, "Snapshot name or --all required"
  end

  def test_returns_usage_error_when_name_and_all_both_provided
    exit_code = Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { all: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_for_name_and_all_conflict
    Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { all: true }, {})
    assert_includes $stderr.string, "Cannot use --all with snapshot name"
  end

  def test_parses_snapshot_name_from_first_arg
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { yes: true }, {})
    assert_equal "snap1", cmd.instance_variable_get(:@snapshot_name)
  end

  def test_parses_vmids_from_option
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100", "101"], yes: true }, {})
    assert_equal [100, 101], cmd.instance_variable_get(:@vmids)
  end

  def test_vmids_empty_when_no_vmid_option
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { yes: true }, {})
    assert_equal [], cmd.instance_variable_get(:@vmids)
  end

  def test_validates_vmid_is_numeric
    Pvectl::Commands::DeleteSnapshot.execute(["snap1"], { vmid: ["abc"], yes: true }, {})
    assert_includes $stderr.string, "Invalid VMID"
  end

  def test_all_mode_with_vmid
    cmd = Pvectl::Commands::DeleteSnapshot.new([], { all: true, vmid: ["100"], yes: true }, {})
    assert cmd.instance_variable_get(:@delete_all)
    assert_equal [100], cmd.instance_variable_get(:@vmids)
  end

  # --- confirmation prompt tests ---

  def test_prompts_for_confirmation_without_yes
    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100"] }, {})
    result = cmd.send(:confirm_operation)

    refute result
  end

  def test_skips_confirmation_with_yes_flag
    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100"], yes: true }, {})
    result = cmd.send(:confirm_operation)

    assert result
  end

  def test_confirmation_prompt_for_named_delete
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new(["before-upgrade"], { vmid: ["100", "101"] }, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "delete snapshot"
    assert_includes output.string, "before-upgrade"
  end

  def test_confirmation_prompt_for_delete_all
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new([], { all: true, vmid: ["100"] }, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "delete ALL snapshots"
  end

  def test_cluster_wide_delete_confirmation
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], {}, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "ALL VMs/CTs"
  end

  def test_single_vm_delete_confirmation
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd = Pvectl::Commands::DeleteSnapshot.new(["snap1"], { vmid: ["100"] }, {})
    cmd.send(:confirm_operation)

    assert_includes output.string, "VM 100"
  end
end
