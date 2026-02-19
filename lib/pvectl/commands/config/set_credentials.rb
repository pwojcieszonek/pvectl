# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config set-credentials` command.
      #
      # Creates a new user or modifies existing credentials in the configuration.
      # Supports two authentication methods:
      # - API Token: --token-id and --token-secret
      # - Password: --username and --password
      #
      # @example Usage with token authentication
      #   pvectl config set-credentials admin --token-id=root@pam!automation --token-secret=xxx-xxx
      #
      # @example Usage with password authentication
      #   pvectl config set-credentials dev-user --username=root@pam --password=secret
      #
      class SetCredentials
        # Executes the set-credentials command.
        #
        # @param user_name [String] name of the user to create or modify
        # @param options [Hash] command options (:token_id, :token_secret, :username, :password)
        # @param global_options [Hash] global CLI options (includes :config)
        # @return [Integer] exit code (0 for success)
        def self.execute(user_name, options, global_options)
          config_path = global_options[:config]
          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          existing_user = service.user(user_name)
          action = existing_user ? "modified" : "created"

          # Use existing values if not provided
          token_id = options[:"token-id"] || options[:token_id] || existing_user&.token_id
          token_secret = options[:"token-secret"] || options[:token_secret] || existing_user&.token_secret
          username = options[:username] || existing_user&.username
          password = options[:password] || existing_user&.password

          # Validate credentials for new users
          if existing_user.nil?
            validation_error = validate_new_user_credentials(token_id, token_secret, username, password)
            return validation_error if validation_error
          else
            # For existing users, validate that partial updates are complete
            validation_error = validate_partial_update(options, existing_user)
            return validation_error if validation_error
          end

          service.set_credentials(
            name: user_name,
            token_id: token_id,
            token_secret: token_secret,
            username: username,
            password: password
          )

          puts "User \"#{user_name}\" #{action}."
          0
        end

        # Validates credentials for a new user.
        #
        # @param token_id [String, nil] API token ID
        # @param token_secret [String, nil] API token secret
        # @param username [String, nil] username
        # @param password [String, nil] password
        # @return [Integer, nil] exit code if validation fails, nil otherwise
        def self.validate_new_user_credentials(token_id, token_secret, username, password)
          has_token_auth = token_id && token_secret
          has_password_auth = username && password

          if !has_token_auth && !has_password_auth
            if token_id && !token_secret
              $stderr.puts "Error: --token-secret is required when using --token-id"
              return ExitCodes::USAGE_ERROR
            elsif token_secret && !token_id
              $stderr.puts "Error: --token-id is required when using --token-secret"
              return ExitCodes::USAGE_ERROR
            elsif username && !password
              $stderr.puts "Error: --password is required when using --username"
              return ExitCodes::USAGE_ERROR
            elsif password && !username
              $stderr.puts "Error: --username is required when using --password"
              return ExitCodes::USAGE_ERROR
            else
              $stderr.puts "Error: credentials required (--token-id/--token-secret or --username/--password)"
              return ExitCodes::USAGE_ERROR
            end
          end

          nil
        end

        # Validates partial update for existing user.
        #
        # @param options [Hash] command options
        # @param existing_user [Models::User] existing user model
        # @return [Integer, nil] exit code if validation fails, nil otherwise
        def self.validate_partial_update(options, existing_user)
          # Check if user is trying to set incomplete token auth
          token_id_provided = options[:"token-id"] || options[:token_id]
          token_secret_provided = options[:"token-secret"] || options[:token_secret]

          if token_id_provided && !token_secret_provided && existing_user.token_secret.nil?
            $stderr.puts "Error: --token-secret is required when using --token-id"
            return ExitCodes::USAGE_ERROR
          end

          if token_secret_provided && !token_id_provided && existing_user.token_id.nil?
            $stderr.puts "Error: --token-id is required when using --token-secret"
            return ExitCodes::USAGE_ERROR
          end

          # Check if user is trying to set incomplete password auth
          username_provided = options[:username]
          password_provided = options[:password]

          if username_provided && !password_provided && existing_user.password.nil?
            $stderr.puts "Error: --password is required when using --username"
            return ExitCodes::USAGE_ERROR
          end

          if password_provided && !username_provided && existing_user.username.nil?
            $stderr.puts "Error: --username is required when using --password"
            return ExitCodes::USAGE_ERROR
          end

          nil
        end
      end
    end
  end
end
