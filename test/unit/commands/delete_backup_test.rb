# frozen_string_literal: true

require "test_helper"

class DeleteBackupTest < Minitest::Test
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
    exit_code = Pvectl::Commands::DeleteBackup.execute(nil, [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_resource_type_not_backup
    exit_code = Pvectl::Commands::DeleteBackup.execute("snapshot", ["volid"], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_volid
    exit_code = Pvectl::Commands::DeleteBackup.execute("backup", [], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_empty_volid
    exit_code = Pvectl::Commands::DeleteBackup.execute("backup", [""], { yes: true }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_yes_flag
    exit_code = Pvectl::Commands::DeleteBackup.execute("backup", ["local:backup/test.vma"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_includes_confirmation_required
    Pvectl::Commands::DeleteBackup.execute("backup", ["local:backup/test.vma"], {}, {})
    assert_includes $stderr.string, "use --yes to confirm"
  end

  def test_error_message_for_missing_volid
    Pvectl::Commands::DeleteBackup.execute("backup", [], { yes: true }, {})
    assert_includes $stderr.string, "volid is required"
  end

  def test_error_message_for_wrong_resource_type
    Pvectl::Commands::DeleteBackup.execute("snapshot", ["volid"], { yes: true }, {})
    assert_includes $stderr.string, "Resource type required (backup)"
  end
end
