# frozen_string_literal: true

# Fixture plugin for PluginLoader integration tests.
# Registers a simple :test_plugin command via PluginLoader.register_plugin.

module TestPlugin
  class Command
    def self.register(cli)
      cli.desc "Test plugin command (fixture)"
      cli.command :test_plugin do |c|
        c.action do |_global, _options, _args|
          puts "test plugin executed"
        end
      end
    end
  end
end

Pvectl::PluginLoader.register_plugin(TestPlugin::Command)
