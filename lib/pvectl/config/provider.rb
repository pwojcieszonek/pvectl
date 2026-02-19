# frozen_string_literal: true

require "yaml"

module Pvectl
  module Config
    # Loads and resolves configuration from multiple sources.
    #
    # Provider handles loading configuration from YAML files and environment
    # variables, then merging them with proper priority to produce a final
    # ResolvedConfig. Priority order (highest to lowest):
    # 1. CLI options
    # 2. Environment variables
    # 3. Configuration file
    #
    # @example Loading configuration
    #   provider = Provider.new
    #   config = provider.resolve(
    #     config_path: "~/.pvectl/config",
    #     cli_options: { context: "production" }
    #   )
    #
    class Provider
      # Mapping of environment variables to configuration keys
      ENV_VARS = {
        "PROXMOX_HOST" => :server,
        "PROXMOX_TOKEN_ID" => :token_id,
        "PROXMOX_TOKEN_SECRET" => :token_secret,
        "PROXMOX_USER" => :username,
        "PROXMOX_PASSWORD" => :password,
        "PROXMOX_VERIFY_SSL" => :verify_ssl,
        "PVECTL_CONTEXT" => :context,
        "PVECTL_CONFIG" => :config_path,
        # Retry/timeout settings
        "PROXMOX_TIMEOUT" => :timeout,
        "PROXMOX_RETRY_COUNT" => :retry_count,
        "PROXMOX_RETRY_DELAY" => :retry_delay,
        "PROXMOX_MAX_RETRY_DELAY" => :max_retry_delay,
        "PROXMOX_RETRY_WRITES" => :retry_writes
      }.freeze

      # Keys that should be parsed as integers
      INTEGER_VARS = %i[timeout retry_count retry_delay max_retry_delay].freeze

      # Keys that should be parsed as booleans
      BOOLEAN_VARS = %i[verify_ssl retry_writes].freeze

      # Checks if a configuration file exists at the given path.
      #
      # @param path [String] path to configuration file
      # @return [Boolean] true if file exists
      def file_exists?(path)
        File.exist?(path)
      end

      # Checks if a file has insecure permissions (readable by group/others).
      #
      # @param path [String] path to file
      # @return [Boolean] true if permissions are insecure
      def insecure_permissions?(path)
        return false unless File.exist?(path)

        mode = File.stat(path).mode & 0o777
        (mode & 0o077) != 0
      end

      # Loads configuration from a YAML file.
      #
      # @param path [String] path to configuration file
      # @return [Hash] parsed configuration hash
      # @raise [ConfigNotFoundError] if file does not exist
      # @raise [InvalidConfigError] if YAML is invalid
      def load_file(path)
        raise ConfigNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        content = File.read(path)
        YAML.safe_load(content, permitted_classes: [Symbol])
      rescue Psych::SyntaxError => e
        raise InvalidConfigError, "Invalid YAML in #{path}: #{e.message}"
      end

      # Loads configuration from environment variables.
      #
      # @return [Hash] configuration values from environment
      # @raise [InvalidConfigError] if integer values are invalid
      def load_env
        result = {}

        ENV_VARS.each do |env_var, config_key|
          value = ENV[env_var]
          next if value.nil? || value.empty?

          result[config_key] = parse_env_value(config_key, value)
        end

        result
      end

      # Resolves the context name from various sources.
      #
      # Priority: CLI > ENV > file
      #
      # @param cli_options [Hash] CLI options (may contain :context)
      # @param file_config [Hash] configuration from file (may contain "current-context")
      # @return [String, nil] resolved context name
      def resolve_context_name(cli_options:, file_config: {})
        cli_options[:context] || ENV["PVECTL_CONTEXT"] || file_config["current-context"]
      end

      # Resolves full configuration by merging all sources.
      #
      # @param config_path [String] path to configuration file
      # @param cli_options [Hash] CLI options
      # @param cluster_override [String, nil] for testing invalid cluster references
      # @return [Models::ResolvedConfig] resolved configuration
      # @raise [ConfigNotFoundError] if config file not found
      # @raise [ContextNotFoundError] if context not found
      # @raise [ClusterNotFoundError] if cluster not found
      # @raise [UserNotFoundError] if user not found
      def resolve(config_path:, cli_options:, cluster_override: nil)
        file_config = load_file(config_path)
        env_config = load_env

        context_name = resolve_context_name(cli_options: cli_options, file_config: file_config)
        context = find_context(file_config, context_name)

        cluster_name = cluster_override || context.cluster_ref
        cluster = find_cluster(file_config, cluster_name)
        user = find_user(file_config, context.user_ref)

        build_resolved_config(
          context: context,
          cluster: cluster,
          user: user,
          env_config: env_config,
          cli_options: cli_options
        )
      end

      private

      # Parses an environment variable value to the appropriate type.
      #
      # @param key [Symbol] configuration key
      # @param value [String] raw environment variable value
      # @return [Object] parsed value (Integer, Boolean, or String)
      # @raise [InvalidConfigError] if value cannot be parsed
      def parse_env_value(key, value)
        if BOOLEAN_VARS.include?(key)
          parse_boolean_env(value)
        elsif INTEGER_VARS.include?(key)
          parse_integer_env(key, value)
        else
          value
        end
      end

      # Parses a boolean environment variable.
      #
      # @param value [String] raw value
      # @return [Boolean] parsed boolean
      def parse_boolean_env(value)
        %w[true 1 yes].include?(value.to_s.downcase)
      end

      # Parses an integer environment variable with validation.
      #
      # @param key [Symbol] configuration key (for error messages)
      # @param value [String] raw environment variable value
      # @return [Integer] parsed integer value
      # @raise [InvalidConfigError] if value is not a valid non-negative integer
      def parse_integer_env(key, value)
        unless value.to_s.match?(/\A\d+\z/)
          raise InvalidConfigError,
                "Invalid integer for #{key.to_s.tr('_', '-')}: '#{value}' " \
                "(must be a non-negative integer)"
        end

        value.to_i
      end

      # Finds a context by name in the configuration.
      #
      # @param config [Hash] configuration hash
      # @param name [String] context name
      # @return [Models::Context] context model
      # @raise [ContextNotFoundError] if context not found
      def find_context(config, name)
        contexts = config["contexts"] || []
        context_hash = contexts.find { |c| c["name"] == name }

        if context_hash.nil?
          available = contexts.map { |c| c["name"] }.join(", ")
          raise ContextNotFoundError, "Context '#{name}' not found. Available: #{available}"
        end

        Models::Context.from_hash(context_hash)
      end

      # Finds a cluster by name in the configuration.
      #
      # @param config [Hash] configuration hash
      # @param name [String] cluster name
      # @return [Models::Cluster] cluster model
      # @raise [ClusterNotFoundError] if cluster not found
      def find_cluster(config, name)
        clusters = config["clusters"] || []
        cluster_hash = clusters.find { |c| c["name"] == name }

        raise ClusterNotFoundError, "Cluster '#{name}' not found in configuration" if cluster_hash.nil?

        Models::Cluster.from_hash(cluster_hash)
      end

      # Finds a user by name in the configuration.
      #
      # @param config [Hash] configuration hash
      # @param name [String] user name
      # @return [Models::User] user model
      # @raise [UserNotFoundError] if user not found
      def find_user(config, name)
        users = config["users"] || []
        user_hash = users.find { |u| u["name"] == name }

        raise UserNotFoundError, "User '#{name}' not found in configuration" if user_hash.nil?

        Models::User.from_hash(user_hash)
      end

      # Builds a ResolvedConfig from merged sources.
      #
      # @param context [Models::Context] resolved context
      # @param cluster [Models::Cluster] resolved cluster
      # @param user [Models::User] resolved user
      # @param env_config [Hash] environment configuration
      # @param cli_options [Hash] CLI options
      # @return [Models::ResolvedConfig] resolved configuration
      def build_resolved_config(context:, cluster:, user:, env_config:, cli_options:)
        # Merge with priority: CLI > ENV > file
        server = env_config[:server] || cluster.server
        verify_ssl = env_config.key?(:verify_ssl) ? env_config[:verify_ssl] : cluster.verify_ssl

        # Determine auth type and credentials
        auth_type, token_id, token_secret, username, password = resolve_auth(user, env_config)

        # Resolve retry/timeout settings with priority: ENV > file
        timeout = env_config[:timeout] || cluster.timeout
        retry_count = env_config[:retry_count] || cluster.retry_count
        retry_delay = env_config[:retry_delay] || cluster.retry_delay
        max_retry_delay = env_config[:max_retry_delay] || cluster.max_retry_delay
        retry_writes = env_config.key?(:retry_writes) ? env_config[:retry_writes] : cluster.retry_writes

        Models::ResolvedConfig.new(
          context_name: context.name,
          server: server,
          verify_ssl: verify_ssl,
          certificate_authority: cluster.certificate_authority,
          auth_type: auth_type,
          token_id: token_id,
          token_secret: token_secret,
          username: username,
          password: password,
          default_node: context.default_node,
          timeout: timeout,
          retry_count: retry_count,
          retry_delay: retry_delay,
          max_retry_delay: max_retry_delay,
          retry_writes: retry_writes
        )
      end

      # Resolves authentication type and credentials.
      #
      # @param user [Models::User] user from config
      # @param env_config [Hash] environment configuration
      # @return [Array] [auth_type, token_id, token_secret, username, password]
      def resolve_auth(user, env_config)
        # ENV token auth takes precedence
        if env_config[:token_id] && env_config[:token_secret]
          return [:token, env_config[:token_id], env_config[:token_secret], nil, nil]
        end

        # ENV password auth
        if env_config[:username] && env_config[:password]
          return [:password, nil, nil, env_config[:username], env_config[:password]]
        end

        # Fall back to user from config
        if user.token_auth?
          [:token, user.token_id, user.token_secret, nil, nil]
        else
          [:password, nil, nil, user.username, user.password]
        end
      end
    end
  end
end
