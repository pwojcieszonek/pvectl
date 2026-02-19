# frozen_string_literal: true

require "test_helper"
require "stringio"

class CommandsContainerLifecycleCommandTest < Minitest::Test
  def test_module_exists
    assert_kind_of Module, Pvectl::Commands::ContainerLifecycleCommand
  end

  def test_including_class_gets_execute_class_method
    assert Pvectl::Commands::StartContainer.respond_to?(:execute)
    assert Pvectl::Commands::StopContainer.respond_to?(:execute)
    assert Pvectl::Commands::ShutdownContainer.respond_to?(:execute)
    assert Pvectl::Commands::RestartContainer.respond_to?(:execute)
  end

  def test_execute_with_empty_ctids_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::StartContainer.execute("container", [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_unsupported_resource_returns_usage_error
    result = Pvectl::Commands::StartContainer.execute("vm", ["100"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_accepts_container_resource_type
    cmd = Pvectl::Commands::StartContainer.new("container", ["200"], {}, {})
    assert_equal ["200"], cmd.instance_variable_get(:@resource_ids)
  end

  def test_accepts_ct_alias
    cmd = Pvectl::Commands::StartContainer.new("ct", ["200"], {}, {})
    assert_equal ["200"], cmd.instance_variable_get(:@resource_ids)
  end

  def test_initializes_with_nil_resource_id_as_empty_array
    cmd = Pvectl::Commands::StartContainer.new("container", nil, {}, {})
    assert_equal [], cmd.instance_variable_get(:@resource_ids)
  end
end

class CommandsStartContainerTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::StartContainer
  end

  def test_includes_container_lifecycle_command
    assert Pvectl::Commands::StartContainer.include?(Pvectl::Commands::ContainerLifecycleCommand)
  end

  def test_operation_constant
    assert_equal :start, Pvectl::Commands::StartContainer::OPERATION
  end

  def test_execute_with_missing_resource_type_returns_usage_error
    result = Pvectl::Commands::StartContainer.execute(nil, ["200"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_unsupported_resource_type_returns_usage_error
    result = Pvectl::Commands::StartContainer.execute("vm", ["200"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_missing_ctid_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::StartContainer.execute("container", [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end
end

class CommandsStopContainerTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::StopContainer
  end

  def test_includes_container_lifecycle_command
    assert Pvectl::Commands::StopContainer.include?(Pvectl::Commands::ContainerLifecycleCommand)
  end

  def test_operation_constant
    assert_equal :stop, Pvectl::Commands::StopContainer::OPERATION
  end
end

class CommandsShutdownContainerTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::ShutdownContainer
  end

  def test_includes_container_lifecycle_command
    assert Pvectl::Commands::ShutdownContainer.include?(Pvectl::Commands::ContainerLifecycleCommand)
  end

  def test_operation_constant
    assert_equal :shutdown, Pvectl::Commands::ShutdownContainer::OPERATION
  end
end

class CommandsRestartContainerTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::RestartContainer
  end

  def test_includes_container_lifecycle_command
    assert Pvectl::Commands::RestartContainer.include?(Pvectl::Commands::ContainerLifecycleCommand)
  end

  def test_operation_constant
    assert_equal :restart, Pvectl::Commands::RestartContainer::OPERATION
  end
end
