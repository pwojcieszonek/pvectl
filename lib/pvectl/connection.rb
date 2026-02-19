# frozen_string_literal: true

require "proxmox_api"
require "timeout"
require_relative "connection/retry_handler"

module Pvectl
  # Wrapper for Proxmox API communication.
  #
  # Connection encapsulates the proxmox-api gem client, providing a unified
  # interface for API access. It handles both token and password authentication,
  # and includes retry logic with exponential backoff and timeout handling.
  #
  # @example Creating a connection with ResolvedConfig
  #   config = service.current_config
  #   connection = Connection.new(config)
  #   connection.verify!
  #   client = connection.client
  #
  # @example Checking API version
  #   version = connection.version
  #   puts "Proxmox VE #{version['release']}"
  #
  # @example Creating a connection with logging
  #   logger = Logger.new($stderr)
  #   connection = Connection.new(config, logger: logger)
  #
  class Connection
    # @return [Config::Models::ResolvedConfig] the configuration used
    attr_reader :config

    # @return [Connection::RetryHandler] the retry handler instance
    attr_reader :retry_handler

    # Creates a new Connection instance.
    #
    # @param config [Config::Models::ResolvedConfig] resolved configuration
    # @param logger [Logger, nil] optional logger for retry messages
    def initialize(config, logger: nil)
      @config = config
      @client = nil
      @logger = logger
      @retry_handler = RetryHandler.new(
        max_retries: config.retry_count,
        base_delay: config.retry_delay,
        max_delay: config.max_retry_delay,
        retry_writes: config.retry_writes,
        logger: logger
      )
    end

    # Returns the Proxmox API client, creating it if necessary.
    #
    # @return [ProxmoxAPI] API client instance
    def client
      @client ||= create_client
    end

    # Verifies the connection to the Proxmox server.
    #
    # Makes a test request to the API version endpoint to verify
    # connectivity and authentication. Uses retry logic for resilience.
    #
    # @return [void]
    # @raise [RuntimeError] if connection fails
    # @raise [Timeout::Error] if request times out
    def verify!
      version
    end

    # Gets the Proxmox server version information.
    #
    # @return [Hash] version information including 'release', 'version', 'repoid'
    # @raise [Timeout::Error] if request times out
    def version
      with_timeout do
        retry_handler.with_retry(method: :get) do
          client.version.get
        end
      end
    end

    private

    # Wraps a block with global timeout.
    #
    # Uses Ruby's Timeout module since proxmox-api gem doesn't support
    # timeout options directly.
    #
    # @yield block to execute
    # @return [Object] result of the block
    # @raise [Timeout::Error] if timeout exceeded
    def with_timeout
      Timeout.timeout(config.timeout) do
        yield
      end
    end

    # Creates the Proxmox API client based on configuration.
    #
    # @return [ProxmoxAPI] configured API client
    def create_client
      host = extract_host
      options = build_client_options

      if config.token_auth?
        ProxmoxAPI.new(
          host,
          token: config.token_id,
          secret: config.token_secret,
          **options
        )
      else
        # Extract username and realm from full username (e.g., "root@pam" -> "root", "pam")
        username, realm = parse_username(config.username)

        ProxmoxAPI.new(
          host,
          username: username,
          password: config.password,
          realm: realm,
          **options
        )
      end
    end

    # Extracts the host from the server URL.
    #
    # @return [String] hostname or IP with optional port
    def extract_host
      uri = URI.parse(config.server)
      host = uri.host
      host = "#{host}:#{uri.port}" if uri.port && uri.port != 8006
      host
    end

    # Builds client options hash.
    #
    # @return [Hash] options for ProxmoxAPI
    def build_client_options
      { verify_ssl: config.verify_ssl }
    end

    # Parses username into username and realm components.
    #
    # @param full_username [String] username with realm (e.g., "root@pam")
    # @return [Array<String, String>] [username, realm]
    def parse_username(full_username)
      if full_username.include?("@")
        parts = full_username.split("@", 2)
        [parts[0], parts[1]]
      else
        [full_username, "pam"]
      end
    end
  end
end
