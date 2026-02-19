# frozen_string_literal: true

require "io/console"

module Pvectl
  module Commands
    # Handler for the `pvectl console vm` command.
    #
    # Opens an interactive terminal console session to a QEMU virtual machine
    # via WebSocket-based termproxy. Requires a running VM and interactive
    # terminal (TTY).
    #
    # @example Open console to VM 100
    #   pvectl console vm 100
    #
    # @example Open console with explicit credentials
    #   pvectl console vm 100 --user root@pam --password secret
    #
    class ConsoleVm
      # Executes the console VM command.
      #
      # @param vmid [String, nil] VM identifier
      # @param options [Hash] command options (:user, :password)
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(vmid, options, global_options)
        new(vmid, options, global_options).execute
      end

      # Initializes a console VM command.
      #
      # @param vmid [String, nil] VM identifier
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(vmid, options, global_options)
        @vmid = vmid
        @options = options
        @global_options = global_options
      end

      # Executes the console flow.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("VMID is required") unless @vmid
        return usage_error("Console requires an interactive terminal (TTY)") unless $stdin.tty?

        load_config
        connection = Pvectl::Connection.new(@config)
        repo = Pvectl::Repositories::Vm.new(connection)

        resource = repo.get(@vmid.to_i)
        return not_found("VM #{@vmid} not found") unless resource

        username, password = resolve_credentials
        return ExitCodes::GENERAL_ERROR if username.nil? || password.nil?

        $stderr.puts "Connecting to VM #{resource.vmid} (#{resource.name || 'unnamed'}) on node #{resource.node}..."

        Pvectl::Services::Console.new.run(
          resource: resource,
          resource_path: resource_path,
          server: @config.server,
          username: username,
          password: password,
          verify_ssl: @config.verify_ssl
        )

        ExitCodes::SUCCESS
      rescue Services::Console::ResourceNotRunningError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      rescue Services::Console::AuthenticationError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::PERMISSION_DENIED
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError,
             Pvectl::Config::MissingCredentialsError
        raise # re-raise for CLI handler
      rescue Errno::ECONNREFUSED, SocketError, Timeout::Error => e
        $stderr.puts "Error: Cannot connect to console: #{e.message}"
        ExitCodes::CONNECTION_ERROR
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      private

      # Returns the API resource path for a QEMU VM.
      #
      # @return [String] resource path segment
      def resource_path
        "qemu/#{@vmid}"
      end

      # Resolves authentication credentials for the console session.
      #
      # Priority: CLI flags > config file > interactive prompt.
      # Extracts default username from token_id when available.
      #
      # @return [Array<String, String>, Array<nil, nil>] [username, password] or [nil, nil] if cancelled
      def resolve_credentials
        username = @options[:user]
        password = @options[:password]

        if username.nil? && password.nil? && @config.username && @config.password
          username = @config.username
          password = @config.password
        end

        if username.nil? && @config.token_id
          # Extract default username from token_id (e.g., "root@pam!pvectl" -> "root@pam")
          default_username = @config.token_id.split("!").first
        end

        # When credentials come from config (username+password pair), use them directly.
        # Otherwise, prompt interactively — always show both prompts so the user knows
        # which username will be used and can change it.
        if password.nil?
          username = prompt_username(username || default_username)
          return [nil, nil] if username.nil?

          password = prompt_password
        end
        return [nil, nil] if password.nil?

        [username, password]
      end

      # Prompts the user for a username.
      #
      # @param default [String, nil] default username to suggest
      # @return [String, nil] entered username or nil if cancelled
      def prompt_username(default = nil)
        prompt = default ? "Username [#{default}]: " : "Username: "
        $stderr.print prompt
        input = $stdin.gets&.strip
        return nil if input.nil?

        input.empty? ? default : input
      end

      # Prompts the user for a password (hidden input).
      #
      # @return [String, nil] entered password or nil if cancelled
      def prompt_password
        $stderr.print "Password: "
        password = $stdin.noecho(&:gets)&.strip
        $stderr.puts # newline after hidden input
        return nil if password.nil? || password.empty?

        password
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Outputs a usage error and returns the exit code.
      #
      # @param message [String] error message
      # @return [Integer] USAGE_ERROR exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Outputs a not-found error and returns the exit code.
      #
      # @param message [String] error message
      # @return [Integer] NOT_FOUND exit code
      def not_found(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::NOT_FOUND
      end
    end
  end
end
