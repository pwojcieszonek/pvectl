# frozen_string_literal: true

require "yaml"
require "fileutils"

module Pvectl
  module Config
    # Handles YAML configuration file persistence.
    #
    # Store manages saving configuration to YAML files with proper
    # secure file permissions. It ensures config files are created
    # with mode 0600 (owner read/write only) and directories with
    # mode 0700 (owner access only).
    #
    # @example Saving configuration
    #   store = Store.new
    #   store.save("~/.pvectl/config", config_hash)
    #
    # @example Updating current context
    #   store.update_current_context("~/.pvectl/config", "production")
    #
    class Store
      # Secure file permissions (owner read/write only)
      SECURE_MODE = 0o600

      # Secure directory permissions (owner access only)
      SECURE_DIR_MODE = 0o700

      # Saves configuration to a YAML file with secure permissions.
      #
      # Creates the parent directory if it doesn't exist, with secure
      # permissions. The config file is written with mode 0600.
      #
      # @param path [String] path to configuration file
      # @param config [Hash] configuration to save
      # @return [void]
      # @raise [Errno::EACCES] if permission denied
      def save(path, config)
        dir = File.dirname(path)

        unless File.directory?(dir)
          FileUtils.mkdir_p(dir)
          File.chmod(SECURE_DIR_MODE, dir)
        end

        File.write(path, YAML.dump(config))
        File.chmod(SECURE_MODE, path)
      end

      # Updates only the current-context in an existing config file.
      #
      # Preserves all other configuration data and file permissions.
      #
      # @param path [String] path to configuration file
      # @param context_name [String] new current context name
      # @return [void]
      # @raise [ConfigNotFoundError] if file does not exist
      def update_current_context(path, context_name)
        raise ConfigNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        config = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
        config["current-context"] = context_name

        # Preserve original permissions
        mode = File.stat(path).mode & 0o777
        File.write(path, YAML.dump(config))
        File.chmod(mode, path)
      end

      # Adds or updates a context in the configuration file.
      #
      # If a context with the same name exists, it is replaced.
      # Otherwise, the new context is appended.
      #
      # @param path [String] path to configuration file
      # @param context [Models::Context] context to add or update
      # @return [void]
      # @raise [ConfigNotFoundError] if file does not exist
      def upsert_context(path, context)
        raise ConfigNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        config = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
        contexts = config["contexts"] ||= []

        # Find existing context index
        existing_index = contexts.find_index { |c| c["name"] == context.name }

        if existing_index
          contexts[existing_index] = context.to_hash
        else
          contexts << context.to_hash
        end

        # Preserve original permissions
        mode = File.stat(path).mode & 0o777
        File.write(path, YAML.dump(config))
        File.chmod(mode, path)
      end

      # Adds or updates a cluster in the configuration file.
      #
      # If a cluster with the same name exists, it is replaced.
      # Otherwise, the new cluster is appended.
      #
      # @param path [String] path to configuration file
      # @param cluster [Models::Cluster] cluster to add or update
      # @return [void]
      # @raise [ConfigNotFoundError] if file does not exist
      def upsert_cluster(path, cluster)
        raise ConfigNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        config = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
        clusters = config["clusters"] ||= []

        # Find existing cluster index
        existing_index = clusters.find_index { |c| c["name"] == cluster.name }

        if existing_index
          clusters[existing_index] = cluster.to_hash
        else
          clusters << cluster.to_hash
        end

        # Preserve original permissions
        mode = File.stat(path).mode & 0o777
        File.write(path, YAML.dump(config))
        File.chmod(mode, path)
      end

      # Adds or updates a user in the configuration file.
      #
      # If a user with the same name exists, it is replaced.
      # Otherwise, the new user is appended.
      #
      # @param path [String] path to configuration file
      # @param user [Models::User] user to add or update
      # @return [void]
      # @raise [ConfigNotFoundError] if file does not exist
      def upsert_user(path, user)
        raise ConfigNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        config = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
        users = config["users"] ||= []

        # Find existing user index
        existing_index = users.find_index { |u| u["name"] == user.name }

        if existing_index
          users[existing_index] = user.to_hash
        else
          users << user.to_hash
        end

        # Preserve original permissions
        mode = File.stat(path).mode & 0o777
        File.write(path, YAML.dump(config))
        File.chmod(mode, path)
      end
    end
  end
end
