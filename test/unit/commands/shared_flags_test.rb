# frozen_string_literal: true

require "test_helper"

class SharedFlagsTest < Minitest::Test
  def test_lifecycle_defines_timeout_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:timeout) },
           "Should define --timeout flag"
  end

  def test_lifecycle_defines_async_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:async) },
           "Should define --async switch"
  end

  def test_lifecycle_defines_wait_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:wait) },
           "Should define --wait switch"
  end

  def test_lifecycle_defines_all_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:all) },
           "Should define --all switch"
  end

  def test_lifecycle_defines_node_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:node) },
           "Should define --node flag"
  end

  def test_lifecycle_defines_yes_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:yes) },
           "Should define --yes switch"
  end

  def test_lifecycle_defines_fail_fast_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:"fail-fast") },
           "Should define --fail-fast switch"
  end

  def test_lifecycle_defines_selector_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:selector) },
           "Should define --selector flag"
  end

  def test_lifecycle_defines_exactly_eight_options
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    total = mock_command.flags.size + mock_command.switches.size
    assert_equal 8, total, "Should define exactly 8 lifecycle flags/switches (got #{total})"
  end

  # Minimal mock for GLI::Command flag/switch API
  class MockGLICommand
    attr_reader :flags, :switches

    def initialize
      @flags = []
      @switches = []
      @last_desc = nil
    end

    def desc(text)
      @last_desc = text
    end

    def default_value(_val); end

    def flag(names, **opts)
      @flags << { names: Array(names).flatten, desc: @last_desc, **opts }
      @last_desc = nil
    end

    def switch(names, **opts)
      @switches << { names: Array(names).flatten, desc: @last_desc, **opts }
      @last_desc = nil
    end
  end
end
