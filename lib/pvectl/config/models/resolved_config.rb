# frozen_string_literal: true

module Pvectl
  module Config
    module Models
      # Represents the final resolved configuration ready for use.
      #
      # ResolvedConfig is an immutable value object containing all settings
      # needed to connect to a Proxmox server. It is created by merging
      # configuration from file, environment variables, and CLI options.
      #
      # @example Creating a resolved config with token auth
      #   config = ResolvedConfig.new(
      #     context_name: "production",
      #     server: "https://pve.example.com:8006",
      #     auth_type: :token,
      #     token_id: "root@pam!automation",
      #     token_secret: "secret-uuid"
      #   )
      #
      # @example Getting connection options for proxmox-api gem
      #   options = config.to_connection_options
      #   # => { server: "https://...", token: "root@pam!automation", ... }
      #
      class ResolvedConfig
        # Default values for retry/timeout settings
        DEFAULT_TIMEOUT = 30
        DEFAULT_RETRY_COUNT = 3
        DEFAULT_RETRY_DELAY = 1
        DEFAULT_MAX_RETRY_DELAY = 30
        DEFAULT_RETRY_WRITES = false

        # @return [String] name of the active context
        attr_reader :context_name

        # @return [String] Proxmox server URL
        attr_reader :server

        # @return [Boolean] whether to verify SSL certificates
        attr_reader :verify_ssl

        # @return [String, nil] path to CA certificate file
        attr_reader :certificate_authority

        # @return [Symbol] authentication type (:token or :password)
        attr_reader :auth_type

        # @return [String, nil] API token ID
        attr_reader :token_id

        # @return [String, nil] API token secret
        attr_reader :token_secret

        # @return [String, nil] username for password auth
        attr_reader :username

        # @return [String, nil] password for password auth
        attr_reader :password

        # @return [String, nil] default node for operations
        attr_reader :default_node

        # @return [Integer] request timeout in seconds
        attr_reader :timeout

        # @return [Integer] maximum retry attempts
        attr_reader :retry_count

        # @return [Integer] base delay between retries in seconds
        attr_reader :retry_delay

        # @return [Integer] maximum delay cap for exponential backoff
        attr_reader :max_retry_delay

        # @return [Boolean] whether to retry write operations
        attr_reader :retry_writes

        # Creates a new ResolvedConfig instance.
        #
        # @param context_name [String] name of the active context
        # @param server [String] Proxmox server URL
        # @param auth_type [Symbol] :token or :password
        # @param verify_ssl [Boolean] whether to verify SSL (default: true)
        # @param certificate_authority [String, nil] path to CA certificate
        # @param token_id [String, nil] API token ID (required for :token auth)
        # @param token_secret [String, nil] API token secret (required for :token auth)
        # @param username [String, nil] username (required for :password auth)
        # @param password [String, nil] password (required for :password auth)
        # @param default_node [String, nil] default node for operations
        # @param timeout [Integer, nil] request timeout (default: 30)
        # @param retry_count [Integer, nil] max retries (default: 3)
        # @param retry_delay [Integer, nil] base delay (default: 1)
        # @param max_retry_delay [Integer, nil] max delay cap (default: 30)
        # @param retry_writes [Boolean, nil] retry writes (default: false)
        def initialize(context_name:, server:, auth_type:, verify_ssl: true,
                       certificate_authority: nil, token_id: nil, token_secret: nil,
                       username: nil, password: nil, default_node: nil,
                       timeout: nil, retry_count: nil, retry_delay: nil,
                       max_retry_delay: nil, retry_writes: nil)
          @context_name = context_name
          @server = server
          @verify_ssl = verify_ssl
          @certificate_authority = certificate_authority
          @auth_type = auth_type
          @token_id = token_id
          @token_secret = token_secret
          @username = username
          @password = password
          @default_node = default_node

          # Apply defaults for retry/timeout settings
          @timeout = timeout || DEFAULT_TIMEOUT
          @retry_count = retry_count || DEFAULT_RETRY_COUNT
          @retry_delay = retry_delay || DEFAULT_RETRY_DELAY
          @max_retry_delay = max_retry_delay || DEFAULT_MAX_RETRY_DELAY
          @retry_writes = retry_writes.nil? ? DEFAULT_RETRY_WRITES : retry_writes
        end

        # Checks if this config uses API token authentication.
        #
        # @return [Boolean] true if auth_type is :token
        def token_auth?
          auth_type == :token
        end

        # Checks if this config uses password authentication.
        #
        # @return [Boolean] true if auth_type is :password
        def password_auth?
          auth_type == :password
        end

        # Converts the config to options hash for proxmox-api gem.
        #
        # @return [Hash] options for ProxmoxAPI.new
        #
        # @example Token auth options
        #   {
        #     server: "https://pve.example.com:8006",
        #     token: "root@pam!automation",
        #     secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        #     verify_ssl: false
        #   }
        #
        # @example Password auth options
        #   {
        #     server: "https://pve.example.com:8006",
        #     username: "root@pam",
        #     password: "secret",
        #     verify_ssl: true
        #   }
        def to_connection_options
          options = {
            server: server,
            verify_ssl: verify_ssl
          }

          if token_auth?
            options[:token] = token_id
            options[:secret] = token_secret
          else
            options[:username] = username
            options[:password] = password
          end

          options
        end
      end
    end
  end
end
