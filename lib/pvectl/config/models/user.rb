# frozen_string_literal: true

module Pvectl
  module Config
    module Models
      # Represents user credentials for Proxmox API authentication.
      #
      # User is an immutable value object supporting two authentication methods:
      # - API Token authentication (token_id + token_secret)
      # - Username/Password authentication (username + password)
      #
      # @example Creating a user with token authentication
      #   user = User.new(
      #     name: "admin",
      #     token_id: "root@pam!automation",
      #     token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      #   )
      #   user.token_auth? #=> true
      #
      # @example Creating a user with password authentication
      #   user = User.new(
      #     name: "admin",
      #     username: "root@pam",
      #     password: "secret"
      #   )
      #   user.password_auth? #=> true
      #
      class User
        # Mask used to hide secrets in output
        SECRET_MASK = "********"

        # @return [String] unique name identifying this user
        attr_reader :name

        # @return [String, nil] API token ID (e.g., "root@pam!tokenid")
        attr_reader :token_id

        # @return [String, nil] API token secret (UUID format)
        attr_reader :token_secret

        # @return [String, nil] username for password auth (e.g., "root@pam")
        attr_reader :username

        # @return [String, nil] password for password auth
        attr_reader :password

        # Creates a new User instance.
        #
        # @param name [String] unique name for this user
        # @param token_id [String, nil] API token ID
        # @param token_secret [String, nil] API token secret
        # @param username [String, nil] username for password auth
        # @param password [String, nil] password for password auth
        def initialize(name:, token_id: nil, token_secret: nil, username: nil, password: nil)
          @name = name
          @token_id = token_id
          @token_secret = token_secret
          @username = username
          @password = password
        end

        # Checks if this user is configured for API token authentication.
        #
        # @return [Boolean] true if both token_id and token_secret are present
        def token_auth?
          !token_id.nil? && !token_id.empty? && !token_secret.nil? && !token_secret.empty?
        end

        # Checks if this user is configured for password authentication.
        #
        # @return [Boolean] true if both username and password are present
        def password_auth?
          !username.nil? && !username.empty? && !password.nil? && !password.empty?
        end

        # Checks if this user has valid credentials for authentication.
        #
        # @return [Boolean] true if token auth or password auth is configured
        def valid?
          token_auth? || password_auth?
        end

        # Creates a User from a kubeconfig-style hash structure.
        #
        # @param hash [Hash] hash with "name" and "user" keys
        # @return [User] new user instance
        #
        # @example Hash structure for token auth
        #   {
        #     "name" => "admin",
        #     "user" => {
        #       "token-id" => "root@pam!token",
        #       "token-secret" => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        #     }
        #   }
        def self.from_hash(hash)
          user_data = hash["user"] || {}

          new(
            name: hash["name"],
            token_id: user_data["token-id"],
            token_secret: user_data["token-secret"],
            username: user_data["username"],
            password: user_data["password"]
          )
        end

        # Converts the user to a kubeconfig-style hash structure.
        #
        # @param mask_secrets [Boolean] whether to mask sensitive values
        # @return [Hash] hash representation suitable for YAML serialization
        def to_hash(mask_secrets: false)
          user_data = {}

          if token_auth?
            user_data["token-id"] = token_id
            user_data["token-secret"] = mask_secrets ? SECRET_MASK : token_secret
          end

          if password_auth?
            user_data["username"] = username
            user_data["password"] = mask_secrets ? SECRET_MASK : password
          end

          {
            "name" => name,
            "user" => user_data
          }
        end
      end
    end
  end
end
