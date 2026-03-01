# frozen_string_literal: true

require "test_helper"

class PullCommandTest < Minitest::Test
  def test_resource_types_mapping
    assert_equal :vm, Pvectl::Commands::Pull::RESOURCE_TYPES["vm"]
    assert_equal :vm, Pvectl::Commands::Pull::RESOURCE_TYPES["vms"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["container"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["containers"]
    assert_equal :container, Pvectl::Commands::Pull::RESOURCE_TYPES["ct"]
  end

  def test_file_prefixes
    assert_equal "vm", Pvectl::Commands::Pull::FILE_PREFIXES[:vm]
    assert_equal "ct", Pvectl::Commands::Pull::FILE_PREFIXES[:container]
  end

  def test_execute_requires_resource_type
    cmd = Pvectl::Commands::Pull.new([], {}, {})
    assert_output(nil, /Resource type is required/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_rejects_unknown_type
    cmd = Pvectl::Commands::Pull.new(["firewall"], {}, {})
    assert_output(nil, /Unknown resource type/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_execute_requires_ids_or_all_or_selector
    cmd = Pvectl::Commands::Pull.new(["vm"], { all: false, selector: nil }, {})
    assert_output(nil, /Provide resource IDs/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end

  def test_all_requires_directory_output
    cmd = Pvectl::Commands::Pull.new(["vm"], { all: true, selector: nil, file: "file.yaml", node: nil }, {})
    assert_output(nil, /directory/) do
      result = cmd.execute
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
    end
  end
end
