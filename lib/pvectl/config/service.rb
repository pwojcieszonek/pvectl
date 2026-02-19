# frozen_string_literal: true

module Pvectl
  module Config
    # Facade for configuration management operations.
    #
    # Service coordinates Provider, Store, and Wizard to provide a unified
    # interface for loading, modifying, and saving configuration. It handles
    # the complete lifecycle of configuration management.
    #
    # @example Loading configuration
    #   service = Service.new
    #   service.load(config: "~/.pvectl/config", context: "production")
    #   puts service.current_config.server
    #
    # @example Switching contexts
    #   service.load(config: path)
    #   service.use_context("development")
    #
    # @example Listing contexts
    #   service.contexts.each do |ctx|
    #     puts ctx.name
    #   end
    #
    class Service
      # Default path for configuration file
      DEFAULT_CONFIG_PATH = File.expand_path("~/.pvectl/config").freeze

      # @return [String] path to loaded configuration file
      attr_reader :config_path

      # @return [Hash] raw configuration hash from file
      attr_reader :raw_config

      # @return [String] name of the current context
      attr_reader :current_context_name

      # Creates a new Service instance.
      #
      # @param provider [Provider, nil] configuration provider (default: new Provider)
      # @param store [Store, nil] configuration store (default: new Store)
      # @param wizard [Wizard, nil] configuration wizard (default: nil, created on demand)
      def initialize(provider: nil, store: nil, wizard: nil)
        @provider = provider || Provider.new
        @store = store || Store.new
        @wizard = wizard
        @loaded = false
      end

      # Loads configuration from file and CLI options.
      #
      # Determines the configuration path from CLI options, environment,
      # or default location. Warns if file permissions are insecure.
      #
      # @param cli_options [Hash] CLI options (:config, :context)
      # @return [Service] self for chaining
      # @raise [ConfigNotFoundError] if config file not found and wizard not available
      # @raise [InvalidConfigError] if config file contains invalid YAML
      def load(cli_options = {})
        @config_path = resolve_config_path(cli_options)

        unless @provider.file_exists?(@config_path)
          raise ConfigNotFoundError, "Configuration file not found: #{@config_path}"
        end

        warn_insecure_permissions if @provider.insecure_permissions?(@config_path)

        @raw_config = @provider.load_file(@config_path)
        @current_context_name = @provider.resolve_context_name(
          cli_options: cli_options,
          file_config: @raw_config
        )
        @resolved_config = nil # Reset cached resolved config
        @loaded = true

        self
      end

      # Returns the current resolved configuration.
      #
      # @return [Models::ResolvedConfig] resolved configuration
      # @raise [ConfigError] if configuration not loaded
      def current_config
        raise ConfigError, "Configuration not loaded. Call #load first." unless @loaded

        @resolved_config ||= @provider.resolve(
          config_path: @config_path,
          cli_options: { context: @current_context_name }
        )
      end

      # Returns all contexts from the configuration.
      #
      # @return [Array<Models::Context>] list of context models
      def contexts
        (@raw_config["contexts"] || []).map do |ctx_hash|
          Models::Context.from_hash(ctx_hash)
        end
      end

      # Returns a specific context by name.
      #
      # @param name [String] context name
      # @return [Models::Context, nil] context or nil if not found
      def context(name)
        contexts.find { |ctx| ctx.name == name }
      end

      # Switches to a different context.
      #
      # Updates both the in-memory state and the configuration file.
      #
      # @param context_name [String] name of context to switch to
      # @return [void]
      # @raise [ContextNotFoundError] if context not found
      def use_context(context_name)
        unless context(context_name)
          available = contexts.map(&:name).join(", ")
          raise ContextNotFoundError, "Context '#{context_name}' not found. Available: #{available}"
        end

        @store.update_current_context(@config_path, context_name)
        @current_context_name = context_name
        @resolved_config = nil # Reset cached config
        @raw_config["current-context"] = context_name
      end

      # Creates or updates a context.
      #
      # @param name [String] context name
      # @param cluster [String] cluster reference
      # @param user [String] user reference
      # @param default_node [String, nil] optional default node
      # @return [Models::Context] the new or updated context
      def set_context(name:, cluster:, user:, default_node: nil)
        new_context = Models::Context.new(
          name: name,
          cluster_ref: cluster,
          user_ref: user,
          default_node: default_node
        )

        @store.upsert_context(@config_path, new_context)

        # Update in-memory config
        refresh_raw_config

        new_context
      end

      # Returns all clusters from the configuration.
      #
      # @return [Array<Models::Cluster>] list of cluster models
      def clusters
        (@raw_config["clusters"] || []).map do |cluster_hash|
          Models::Cluster.from_hash(cluster_hash)
        end
      end

      # Returns a specific cluster by name.
      #
      # @param name [String] cluster name
      # @return [Models::Cluster, nil] cluster or nil if not found
      def cluster(name)
        clusters.find { |c| c.name == name }
      end

      # Creates or updates a cluster.
      #
      # @param name [String] cluster name
      # @param server [String] Proxmox server URL
      # @param verify_ssl [Boolean] whether to verify SSL (default: true)
      # @param certificate_authority [String, nil] path to CA certificate
      # @return [Models::Cluster] the new or updated cluster
      def set_cluster(name:, server:, verify_ssl: true, certificate_authority: nil)
        new_cluster = Models::Cluster.new(
          name: name,
          server: server,
          verify_ssl: verify_ssl,
          certificate_authority: certificate_authority
        )

        @store.upsert_cluster(@config_path, new_cluster)

        # Update in-memory config
        refresh_raw_config

        new_cluster
      end

      # Returns all users from the configuration.
      #
      # @return [Array<Models::User>] list of user models
      def users
        (@raw_config["users"] || []).map do |user_hash|
          Models::User.from_hash(user_hash)
        end
      end

      # Returns a specific user by name.
      #
      # @param name [String] user name
      # @return [Models::User, nil] user or nil if not found
      def user(name)
        users.find { |u| u.name == name }
      end

      # Creates or updates user credentials.
      #
      # @param name [String] user name
      # @param token_id [String, nil] API token ID
      # @param token_secret [String, nil] API token secret
      # @param username [String, nil] username for password auth
      # @param password [String, nil] password for password auth
      # @return [Models::User] the new or updated user
      def set_credentials(name:, token_id: nil, token_secret: nil, username: nil, password: nil)
        new_user = Models::User.new(
          name: name,
          token_id: token_id,
          token_secret: token_secret,
          username: username,
          password: password
        )

        @store.upsert_user(@config_path, new_user)

        # Update in-memory config
        refresh_raw_config

        new_user
      end

      # Returns configuration with secrets masked for display.
      #
      # @return [Hash] configuration with masked secrets
      def masked_config
        config = deep_copy(@raw_config)

        (config["users"] || []).each do |user|
          user_data = user["user"] || {}
          user_data["token-secret"] = "********" if user_data["token-secret"]
          user_data["password"] = "********" if user_data["password"]
        end

        config
      end

      # Saves the current configuration to file.
      #
      # @return [void]
      def save
        @store.save(@config_path, @raw_config)
      end

      private

      # Resolves the configuration file path.
      #
      # Priority: CLI option > ENV > default
      #
      # @param cli_options [Hash] CLI options
      # @return [String] resolved path
      def resolve_config_path(cli_options)
        cli_options[:config] ||
          ENV["PVECTL_CONFIG"] ||
          DEFAULT_CONFIG_PATH
      end

      # Outputs a warning about insecure file permissions.
      #
      # @return [void]
      def warn_insecure_permissions
        $stderr.puts "Warning: Configuration file has insecure permissions. " \
                     "Consider running: chmod 600 #{@config_path}"
      end

      # Refreshes the raw configuration from disk.
      #
      # @return [void]
      def refresh_raw_config
        @raw_config = @provider.load_file(@config_path)
      end

      # Creates a deep copy of a hash.
      #
      # @param obj [Object] object to copy
      # @return [Object] deep copy
      def deep_copy(obj)
        case obj
        when Hash
          obj.transform_values { |v| deep_copy(v) }
        when Array
          obj.map { |v| deep_copy(v) }
        else
          obj
        end
      end
    end
  end
end
