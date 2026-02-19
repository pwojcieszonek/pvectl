# frozen_string_literal: true

module Pvectl
  module Config
    # Interactive configuration wizard for first-time setup.
    #
    # Wizard guides users through initial configuration by prompting
    # for server URL, authentication credentials, and SSL settings.
    # It only runs when stdin is a TTY (not in pipes or scripts).
    #
    # @example Checking if wizard is available
    #   if Wizard.available?
    #     wizard = Wizard.new
    #     config = wizard.run
    #   end
    #
    # @example Using custom prompt (for testing)
    #   wizard = Wizard.new(prompt: mock_prompt)
    #   config = wizard.run
    #
    class Wizard
      # Checks if the wizard can run (stdin is a TTY).
      #
      # @return [Boolean] true if stdin is a TTY
      def self.available?
        $stdin.tty?
      end

      # Creates a new Wizard instance.
      #
      # @param prompt [Object, nil] prompt object for user input (default: built-in)
      def initialize(prompt: nil)
        @prompt = prompt || create_default_prompt
      end

      # Runs the interactive wizard and returns configuration.
      #
      # @return [Hash] configuration hash ready for YAML serialization
      def run
        server = prompt_server
        verify_ssl = prompt_ssl
        auth_type = prompt_auth_type
        credentials = prompt_credentials(auth_type)
        context_name = prompt_context_name

        build_config(
          server: server,
          verify_ssl: verify_ssl,
          auth_type: auth_type,
          credentials: credentials,
          context_name: context_name
        )
      end

      private

      attr_reader :prompt

      # Creates a default prompt using TTY::Prompt if available.
      #
      # @return [Object] prompt object
      def create_default_prompt
        # Try to load TTY::Prompt if available
        begin
          require "tty-prompt"
          TTY::Prompt.new
        rescue LoadError
          # Fallback to simple prompt
          SimplePrompt.new
        end
      end

      # Prompts for the Proxmox server URL.
      #
      # @return [String] server URL
      def prompt_server
        prompt.ask("Proxmox server URL (e.g., https://pve.example.com:8006):")
      end

      # Prompts for SSL verification preference.
      #
      # @return [Boolean] true if SSL should be verified
      def prompt_ssl
        prompt.yes?("Verify SSL certificate?")
      end

      # Prompts for authentication type selection.
      #
      # @return [Symbol] :token or :password
      def prompt_auth_type
        prompt.select("Authentication method:", [
          { name: "API Token (recommended)", value: :token },
          { name: "Username/Password", value: :password }
        ])
      end

      # Prompts for authentication credentials.
      #
      # @param auth_type [Symbol] :token or :password
      # @return [Hash] credentials hash
      def prompt_credentials(auth_type)
        if auth_type == :token
          {
            token_id: prompt.ask("Token ID (e.g., root@pam!tokenid):"),
            token_secret: prompt.mask("Token Secret:")
          }
        else
          {
            username: prompt.ask("Username (e.g., root@pam):"),
            password: prompt.mask("Password:")
          }
        end
      end

      # Prompts for context name.
      #
      # @return [String] context name
      def prompt_context_name
        prompt.ask("Context name:", default: "default")
      end

      # Builds the configuration hash from collected data.
      #
      # @param server [String] server URL
      # @param verify_ssl [Boolean] SSL verification
      # @param auth_type [Symbol] authentication type
      # @param credentials [Hash] authentication credentials
      # @param context_name [String] context name
      # @return [Hash] configuration hash
      def build_config(server:, verify_ssl:, auth_type:, credentials:, context_name:)
        cluster_name = context_name
        user_name = "#{context_name}-user"

        {
          "apiVersion" => "pvectl/v1",
          "kind" => "Config",
          "clusters" => [
            {
              "name" => cluster_name,
              "cluster" => {
                "server" => server,
                "insecure-skip-tls-verify" => !verify_ssl
              }
            }
          ],
          "users" => [
            build_user_config(user_name, auth_type, credentials)
          ],
          "contexts" => [
            {
              "name" => context_name,
              "context" => {
                "cluster" => cluster_name,
                "user" => user_name
              }
            }
          ],
          "current-context" => context_name
        }
      end

      # Builds user configuration hash.
      #
      # @param name [String] user name
      # @param auth_type [Symbol] :token or :password
      # @param credentials [Hash] credentials
      # @return [Hash] user configuration
      def build_user_config(name, auth_type, credentials)
        user_data = if auth_type == :token
                      {
                        "token-id" => credentials[:token_id],
                        "token-secret" => credentials[:token_secret]
                      }
                    else
                      {
                        "username" => credentials[:username],
                        "password" => credentials[:password]
                      }
                    end

        {
          "name" => name,
          "user" => user_data
        }
      end

      # Validates server URL format.
      #
      # @param url [String] URL to validate
      # @return [Boolean] true if valid
      def valid_server_url?(url)
        return false if url.nil? || url.empty?

        uri = URI.parse(url)
        uri.scheme == "https" && !uri.host.nil?
      rescue URI::InvalidURIError
        false
      end

      # Validates token ID format.
      #
      # @param token_id [String] token ID to validate
      # @return [Boolean] true if valid (contains @ and !)
      def valid_token_id?(token_id)
        return false if token_id.nil? || token_id.empty?

        token_id.include?("@") && token_id.include?("!")
      end
    end

    # Simple fallback prompt when TTY::Prompt is not available.
    #
    # Provides basic input methods without fancy formatting.
    #
    class SimplePrompt
      # Asks a question and returns the answer.
      #
      # @param question [String] question to ask
      # @param default [String, nil] default value
      # @return [String] user input
      def ask(question, default: nil)
        print "#{question} "
        print "[#{default}] " if default
        input = $stdin.gets&.chomp
        input.nil? || input.empty? ? default : input
      end

      # Asks a yes/no question.
      #
      # @param question [String] question to ask
      # @return [Boolean] true for yes
      def yes?(question, **)
        print "#{question} (y/n) "
        input = $stdin.gets&.chomp&.downcase
        %w[y yes].include?(input)
      end

      # Prompts for selection from choices.
      #
      # @param question [String] question to ask
      # @param choices [Array] list of choices
      # @return [Object] selected value
      def select(question, choices, **)
        puts question
        choices.each_with_index do |choice, index|
          name = choice.is_a?(Hash) ? choice[:name] : choice
          puts "  #{index + 1}. #{name}"
        end
        print "Enter number: "
        input = $stdin.gets&.chomp&.to_i || 1
        choice = choices[input - 1] || choices.first
        choice.is_a?(Hash) ? choice[:value] : choice
      end

      # Asks for masked input (password).
      #
      # @param question [String] question to ask
      # @return [String] user input
      def mask(question, **)
        print "#{question} "
        begin
          $stdin.noecho { $stdin.gets&.chomp }
        rescue NoMethodError
          # Fallback if noecho not available
          $stdin.gets&.chomp
        ensure
          puts
        end
      end

      def ok(_message); end

      def warn(_message); end

      def error(_message); end
    end
  end
end
