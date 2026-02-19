# frozen_string_literal: true

require "test_helper"

class DeleteSnapshotTest < Minitest::Test
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

  def test_returns_usage_error_when_resource_type_nil
    exit_code = Pvectl::Commands::DeleteSnapshot.execute(nil, [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_resource_type_not_snapshot
    exit_code = Pvectl::Commands::DeleteSnapshot.execute("vm", ["100", "snap1"], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_only_one_arg
    exit_code = Pvectl::Commands::DeleteSnapshot.execute("snapshot", ["100"], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_args
    exit_code = Pvectl::Commands::DeleteSnapshot.execute("snapshot", [], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_yes_flag
    exit_code = Pvectl::Commands::DeleteSnapshot.execute("snapshot", ["100", "snap1"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_includes_confirmation_required
    Pvectl::Commands::DeleteSnapshot.execute("snapshot", ["100", "snap1"], {}, {})
    assert_includes $stderr.string, "use --yes to confirm"
  end

  def test_parses_single_vmid_and_snapshot_name
    # Should ask for --yes, not complain about missing args
    Pvectl::Commands::DeleteSnapshot.execute("snapshot", ["100", "snap1"], {}, {})
    assert_includes $stderr.string, "--yes"
    refute_includes $stderr.string, "VMID and snapshot name required"
  end

  def test_parses_multiple_vmids_and_snapshot_name
    Pvectl::Commands::DeleteSnapshot.execute("snapshot", ["100", "101", "102", "snap1"], {}, {})
    # Should ask for --yes
    assert_includes $stderr.string, "--yes"
  end

  def test_error_message_for_unsupported_resource
    Pvectl::Commands::DeleteSnapshot.execute("vm", ["100", "snap1"], { yes: true }, {})
    assert_includes $stderr.string, "Unsupported resource"
  end
end
