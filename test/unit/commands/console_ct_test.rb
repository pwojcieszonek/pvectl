# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/pvectl/commands/console_ct"

class CommandsConsoleCtTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::ConsoleCt
  end

  def test_execute_with_missing_ctid_returns_usage_error
    exit_code = Pvectl::Commands::ConsoleCt.execute(nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_execute_with_non_tty_returns_usage_error
    original_stdin = $stdin
    $stdin = StringIO.new
    exit_code = Pvectl::Commands::ConsoleCt.execute("200", {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  ensure
    $stdin = original_stdin
  end

  def test_resource_path_format
    cmd = Pvectl::Commands::ConsoleCt.new("200", {}, {})
    assert_equal "lxc/200", cmd.send(:resource_path)
  end
end
