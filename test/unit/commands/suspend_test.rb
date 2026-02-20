# frozen_string_literal: true

require "test_helper"

class CommandsSuspendTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::Suspend
  end

  def test_includes_lifecycle_command
    assert Pvectl::Commands::Suspend.include?(Pvectl::Commands::VmLifecycleCommand)
  end

  def test_operation_constant
    assert_equal :suspend, Pvectl::Commands::Suspend::OPERATION
  end

  def test_execute_with_missing_resource_type_returns_usage_error
    result = Pvectl::Commands::Suspend.execute(nil, ["100"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_unsupported_resource_type_returns_usage_error
    result = Pvectl::Commands::Suspend.execute("node", ["pve1"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_missing_vmid_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::Suspend.execute("vm", [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_nil_vmid_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::Suspend.execute("vm", nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_responds_to_execute
    assert Pvectl::Commands::Suspend.respond_to?(:execute)
  end
end
