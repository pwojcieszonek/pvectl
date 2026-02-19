# frozen_string_literal: true

require "test_helper"

class LogsCommandBasicTest < Minitest::Test
  def test_command_class_exists
    assert_kind_of Class, Pvectl::Commands::Logs::Command
  end

  def test_execute_class_method_exists
    assert_respond_to Pvectl::Commands::Logs::Command, :execute
  end
end

class LogsCommandMissingResourceTypeTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_resource_type_nil
    exit_code = Pvectl::Commands::Logs::Command.execute(nil, nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_when_resource_type_nil
    Pvectl::Commands::Logs::Command.execute(nil, nil, {}, {})
    assert_includes $stderr.string, "resource type is required"
  end
end

class LogsCommandUnknownResourceTypeTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_for_unknown_resource
    exit_code = Pvectl::Commands::Logs::Command.execute("unknown", "id", {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_for_unknown_resource
    Pvectl::Commands::Logs::Command.execute("unknown", "id", {}, {})
    assert_includes $stderr.string, "Unknown resource type: unknown"
  end
end

class LogsCommandMissingResourceIdTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_resource_id_nil
    exit_code = Pvectl::Commands::Logs::Command.execute("vm", nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_when_resource_id_nil
    Pvectl::Commands::Logs::Command.execute("vm", nil, {}, {})
    assert_includes $stderr.string, "resource ID is required"
  end
end

class LogsCommandVmDelegationTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_delegates_to_handler_and_formats_output
    entry = Pvectl::Models::TaskEntry.new(
      type: "qmstart", status: "stopped", exitstatus: "OK",
      starttime: 1_708_300_000, endtime: 1_708_300_005,
      user: "root@pam", node: "pve1"
    )

    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [entry], [], vmid: 100, resource_type: "vm",
      all_nodes: false, limit: 50, since: nil, until_time: nil,
      type_filter: nil, status_filter: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TaskEntry.new

    command = Pvectl::Commands::Logs::Command.new("vm", "100", {}, {}, handler: mock_handler)
    exit_code = command.execute

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
    assert_includes $stdout.string, "qmstart"
    mock_handler.verify
  end
end

class LogsCommandJournalSwitchTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_uses_journal_handler_when_journal_flag_set
    entry = Pvectl::Models::JournalEntry.new(n: 1, t: "journal line")

    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [entry], [], node: "pve1", limit: 50,
      since: nil, until_time: nil, service: nil
    mock_handler.expect :presenter, Pvectl::Presenters::JournalEntry.new

    command = Pvectl::Commands::Logs::Command.new(
      "node", "pve1", { journal: true }, {},
      journal_handler: mock_handler
    )
    exit_code = command.execute

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
    assert_includes $stdout.string, "journal line"
    mock_handler.verify
  end
end

class LogsCommandResourceNotFoundTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_not_found_exit_code
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, nil do |**_|
      raise Pvectl::ResourceNotFoundError, "VM not found: 999"
    end

    command = Pvectl::Commands::Logs::Command.new("vm", "999", {}, {}, handler: mock_handler)
    exit_code = command.execute

    assert_equal Pvectl::ExitCodes::NOT_FOUND, exit_code
    assert_includes $stderr.string, "VM not found: 999"
  end
end
