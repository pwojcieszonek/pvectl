# frozen_string_literal: true

module Pvectl
  module Config
    # Base error class for all configuration-related exceptions.
    #
    # All configuration errors inherit from this class, allowing
    # consumers to catch all config errors with a single rescue clause.
    #
    # @example Catching all configuration errors
    #   begin
    #     service.load(config: path)
    #   rescue Pvectl::Config::ConfigError => e
    #     $stderr.puts "Configuration error: #{e.message}"
    #     exit Pvectl::ExitCodes::CONFIG_ERROR
    #   end
    #
    class ConfigError < StandardError; end

    # Raised when the configuration file cannot be found at the specified path.
    #
    # @example
    #   raise ConfigNotFoundError, "Configuration file not found: ~/.pvectl/config"
    #
    class ConfigNotFoundError < ConfigError; end

    # Raised when the configuration file contains invalid YAML or structure.
    #
    # @example
    #   raise InvalidConfigError, "Invalid YAML syntax at line 5"
    #
    class InvalidConfigError < ConfigError; end

    # Raised when a referenced context does not exist in the configuration.
    #
    # @example
    #   raise ContextNotFoundError, "Context 'production' not found"
    #
    class ContextNotFoundError < ConfigError; end

    # Raised when a context references a cluster that does not exist.
    #
    # @example
    #   raise ClusterNotFoundError, "Cluster 'main' not found in configuration"
    #
    class ClusterNotFoundError < ConfigError; end

    # Raised when a context references a user that does not exist.
    #
    # @example
    #   raise UserNotFoundError, "User 'admin' not found in configuration"
    #
    class UserNotFoundError < ConfigError; end

    # Raised when no valid credentials are available for authentication.
    #
    # @example
    #   raise MissingCredentialsError, "No valid credentials found. Provide token or username/password"
    #
    class MissingCredentialsError < ConfigError; end
  end
end
