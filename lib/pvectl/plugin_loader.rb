# frozen_string_literal: true

module Pvectl
  # Discovers and loads commands from built-in sources and external plugins.
  #
  # Loading order:
  # 1. Built-in commands (BUILTIN_COMMANDS list)
  # 2. Gem-based plugins (pvectl-plugin-* gems)
  # 3. Directory-based plugins (~/.pvectl/plugins/*.rb)
  #
  # Order matters: built-in commands register first (including their
  # ResourceRegistries), then plugins can extend those registries.
  #
  # @example Plugin registration from a gem
  #   Pvectl::PluginLoader.register_plugin(MyPlugin::Command)
  #
  class PluginLoader
    # Built-in commands that ship with pvectl.
    # Each must implement .register(cli).
    BUILTIN_COMMANDS = [
      Commands::Ping,
      Commands::Config::Command,
      Commands::Get::Command,
    ].freeze

    @registered_plugins = []

    class << self
      # Registers an external plugin command for loading.
      #
      # @param klass [Class] plugin class that implements .register(cli)
      # @return [void]
      def register_plugin(klass)
        @registered_plugins << klass
      end

      # Returns currently registered plugins (for testing).
      #
      # @return [Array<Class>] registered plugin classes
      def registered_plugins
        @registered_plugins.dup
      end

      # Loads all commands: built-in, gem plugins, directory plugins.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def load_all(cli)
        load_builtins(cli)
        load_gem_plugins(cli)
        load_directory_plugins(cli)
      end

      # Loads built-in commands.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def load_builtins(cli)
        BUILTIN_COMMANDS.each { |cmd| cmd.register(cli) }
      end

      # Discovers and loads gem-based plugins.
      #
      # Searches for gems matching pvectl-plugin-* via
      # Gem.find_files("pvectl_plugin/register").
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def load_gem_plugins(cli)
        Gem.find_files("pvectl_plugin/register").each do |register_file|
          require register_file
        rescue StandardError => e
          warn "Warning: Failed to load plugin #{register_file}: #{e.message}"
          warn e.backtrace.join("\n") if ENV["GLI_DEBUG"] == "true"
        end
        flush_registered_plugins(cli)
      end

      # Discovers and loads directory-based plugins.
      #
      # Scans ~/.pvectl/plugins/*.rb for plugin files.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def load_directory_plugins(cli)
        return unless Dir.exist?(directory_plugins_path)

        Dir.glob(File.join(directory_plugins_path, "*.rb")).sort.each do |plugin_file|
          require plugin_file
        rescue StandardError => e
          warn "Warning: Failed to load plugin #{plugin_file}: #{e.message}"
          warn e.backtrace.join("\n") if ENV["GLI_DEBUG"] == "true"
        end
        flush_registered_plugins(cli)
      end

      # Returns the directory path for local plugins.
      #
      # @return [String] plugins directory path
      def directory_plugins_path
        File.expand_path("~/.pvectl/plugins")
      end

      # Calls register on all queued plugins and clears the queue.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def flush_registered_plugins(cli)
        @registered_plugins.each do |klass|
          klass.register(cli)
        rescue StandardError => e
          warn "Warning: Failed to register plugin #{klass}: #{e.message}"
          warn e.backtrace.join("\n") if ENV["GLI_DEBUG"] == "true"
        end
        @registered_plugins.clear
      end

      # Resets state (for testing).
      #
      # @return [void]
      # @api private
      def reset!
        @registered_plugins = []
      end
    end
  end
end
