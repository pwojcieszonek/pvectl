# frozen_string_literal: true

require "test_helper"

class PluginLoaderTest < Minitest::Test
  def setup
    Pvectl::PluginLoader.reset!
  end

  def test_register_plugin_adds_to_registered_plugins
    mock_plugin = Class.new do
      def self.register(_cli); end
    end
    Pvectl::PluginLoader.register_plugin(mock_plugin)

    assert_includes Pvectl::PluginLoader.registered_plugins, mock_plugin
  end

  def test_registered_plugins_returns_copy
    mock_plugin = Class.new do
      def self.register(_cli); end
    end
    Pvectl::PluginLoader.register_plugin(mock_plugin)

    list = Pvectl::PluginLoader.registered_plugins
    list.clear
    refute_empty Pvectl::PluginLoader.registered_plugins,
                 "Should return a copy, not the internal list"
  end

  def test_flush_registered_plugins_calls_register_and_clears
    mock_cli = Object.new
    calls = []
    mock_plugin = Class.new do
      define_singleton_method(:register) { |cli| calls << cli }
    end

    Pvectl::PluginLoader.register_plugin(mock_plugin)
    Pvectl::PluginLoader.flush_registered_plugins(mock_cli)

    assert_equal [mock_cli], calls
    assert_empty Pvectl::PluginLoader.registered_plugins
  end

  def test_flush_handles_broken_plugin_gracefully
    mock_cli = Object.new
    broken_plugin = Class.new do
      define_singleton_method(:register) { |_cli| raise "Boom!" }
    end

    Pvectl::PluginLoader.register_plugin(broken_plugin)

    assert_output(nil, /Warning: Failed to register plugin/) do
      Pvectl::PluginLoader.flush_registered_plugins(mock_cli)
    end

    assert_empty Pvectl::PluginLoader.registered_plugins,
                 "Should clear queue even after error"
  end

  def test_reset_clears_registered_plugins
    mock_plugin = Class.new do
      def self.register(_cli); end
    end
    Pvectl::PluginLoader.register_plugin(mock_plugin)
    Pvectl::PluginLoader.reset!

    assert_empty Pvectl::PluginLoader.registered_plugins
  end

  def test_load_builtins_calls_register_on_each_builtin
    mock_cli = Object.new
    register_calls = []
    mock_command = Class.new do
      define_singleton_method(:register) { |cli| register_calls << cli }
    end

    original = Pvectl::PluginLoader::BUILTIN_COMMANDS
    Pvectl::PluginLoader.send(:remove_const, :BUILTIN_COMMANDS)
    Pvectl::PluginLoader.const_set(:BUILTIN_COMMANDS, [mock_command].freeze)

    Pvectl::PluginLoader.load_builtins(mock_cli)

    assert_equal [mock_cli], register_calls
  ensure
    Pvectl::PluginLoader.send(:remove_const, :BUILTIN_COMMANDS)
    Pvectl::PluginLoader.const_set(:BUILTIN_COMMANDS, original)
  end

  def test_directory_plugins_path_returns_expected_path
    expected = File.expand_path("~/.pvectl/plugins")
    assert_equal expected, Pvectl::PluginLoader.directory_plugins_path
  end

  def test_load_directory_plugins_skips_nonexistent_dir
    mock_cli = Object.new
    # Should not raise when directory doesn't exist
    Pvectl::PluginLoader.stub(:directory_plugins_path, "/nonexistent/path") do
      Pvectl::PluginLoader.load_directory_plugins(mock_cli)
    end
  end
end
