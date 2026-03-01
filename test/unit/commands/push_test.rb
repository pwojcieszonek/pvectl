# frozen_string_literal: true

require "test_helper"

class PushCommandTest < Minitest::Test
  def test_resource_types_mapping
    assert_equal :vm, Pvectl::Commands::Push::RESOURCE_TYPES["vm"]
    assert_equal :vm, Pvectl::Commands::Push::RESOURCE_TYPES["vms"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["container"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["containers"]
    assert_equal :container, Pvectl::Commands::Push::RESOURCE_TYPES["ct"]
  end

  def test_execute_requires_file_path
    cmd = Pvectl::Commands::Push.new([], {}, {})
    assert_output(nil, /File or directory path is required/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_with_nonexistent_file
    cmd = Pvectl::Commands::Push.new(["/nonexistent/path.yaml"], {}, {})
    assert_output(nil, /No YAML files found|File not found/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_parse_resource_type_returns_nil_for_file_path
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["vm-100.yaml"]
    result = cmd.send(:parse_resource_type, args)
    assert_nil result
    assert_equal ["vm-100.yaml"], args
  end

  def test_parse_resource_type_extracts_known_type
    cmd = Pvectl::Commands::Push.new([], {}, {})
    args = ["vm", "vm-100.yaml"]
    result = cmd.send(:parse_resource_type, args)
    assert_equal :vm, result
    assert_equal ["vm-100.yaml"], args
  end
end
