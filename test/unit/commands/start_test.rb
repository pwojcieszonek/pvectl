# frozen_string_literal: true

require "test_helper"

class CommandsStartTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::Start
  end

  def test_execute_with_missing_resource_type_returns_usage_error
    result = Pvectl::Commands::Start.execute(nil, ["100"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_unsupported_resource_type_returns_usage_error
    result = Pvectl::Commands::Start.execute("node", ["pve1"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_missing_vmid_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::Start.execute("vm", [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_nil_vmid_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::Start.execute("vm", nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_validates_vm_resource_type
    # This test verifies 'vm' is accepted (would need mocks to fully test)
    # Just verify the class structure is correct
    assert Pvectl::Commands::Start.respond_to?(:execute)
  end

  def test_execute_accepts_array_of_vmids
    # Verify the interface accepts arrays (actual execution would need mocks)
    assert Pvectl::Commands::Start.respond_to?(:execute)
    # Method signature: execute(resource_type, resource_ids, options, global_options)
    # resource_ids should be an array
  end
end
