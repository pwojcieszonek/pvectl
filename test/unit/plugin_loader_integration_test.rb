# frozen_string_literal: true

require "test_helper"

class PluginLoaderIntegrationTest < Minitest::Test
  def test_load_builtins_registers_all_expected_commands
    # Create a fresh GLI app to test registration
    test_app = Class.new do
      extend GLI::App
    end

    Pvectl::PluginLoader.load_builtins(test_app)

    expected_commands = %i[get top logs describe ping start stop shutdown
                          restart reset suspend resume create delete edit
                          clone migrate rollback restore config]

    expected_commands.each do |cmd|
      assert test_app.commands.key?(cmd),
             "Expected command :#{cmd} to be registered, but it was not. " \
             "Registered commands: #{test_app.commands.keys.sort}"
    end
  end

  def test_load_builtins_registers_exactly_expected_count
    test_app = Class.new do
      extend GLI::App
    end

    Pvectl::PluginLoader.load_builtins(test_app)

    # GLI adds :help and :_doc by default, plus our 20 built-in commands
    user_commands = test_app.commands.keys - [:help, :_doc]
    expected_count = 20
    assert_equal expected_count, user_commands.size,
                 "Expected #{expected_count} user commands, got #{user_commands.size}: #{user_commands.sort}"
  end

  def test_load_directory_plugins_loads_fixture_plugin
    test_app = Class.new do
      extend GLI::App
    end

    fixture_dir = File.expand_path("fixtures/plugins", __dir__)

    Pvectl::PluginLoader.reset!
    Pvectl::PluginLoader.stub(:directory_plugins_path, fixture_dir) do
      Pvectl::PluginLoader.load_directory_plugins(test_app)
    end

    assert test_app.commands.key?(:test_plugin),
           "Fixture plugin should register :test_plugin command. " \
           "Registered: #{test_app.commands.keys.sort}"
  end

  def test_load_directory_plugins_handles_broken_fixture
    test_app = Class.new do
      extend GLI::App
    end

    fixture_dir = File.expand_path("fixtures/broken_plugins", __dir__)

    Pvectl::PluginLoader.reset!
    _out, err = capture_io do
      Pvectl::PluginLoader.stub(:directory_plugins_path, fixture_dir) do
        Pvectl::PluginLoader.load_directory_plugins(test_app)
      end
    end

    assert_match(/Warning: Failed to load plugin/, err)
  end
end
