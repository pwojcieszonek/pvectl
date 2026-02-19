# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/pvectl/commands/console_vm"

class CommandsConsoleVmTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::ConsoleVm
  end

  def test_execute_with_missing_vmid_returns_usage_error
    exit_code = Pvectl::Commands::ConsoleVm.execute(nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_execute_with_non_tty_returns_usage_error
    original_stdin = $stdin
    $stdin = StringIO.new
    exit_code = Pvectl::Commands::ConsoleVm.execute("100", {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  ensure
    $stdin = original_stdin
  end

  def test_resource_path_format
    cmd = Pvectl::Commands::ConsoleVm.new("100", {}, {})
    assert_equal "qemu/100", cmd.send(:resource_path)
  end
end
