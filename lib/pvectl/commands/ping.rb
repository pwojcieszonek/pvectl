# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl ping` command.
    #
    # Verifies connectivity to the Proxmox cluster by calling the version
    # endpoint and measuring response time. Provides a quick health check
    # without detailed resource information.
    #
    # @example Basic usage
    #   pvectl ping
    #   # Output: OK - Connected to pve1.example.com
    #
    # @example Wide output with latency
    #   pvectl ping -o wide
    #   # Output: OK - Connected to pve1.example.com | Latency: 45ms
    #
    # @example JSON output for scripts
    #   pvectl ping -o json
    #   # Output: {"status":"ok","server":"pve1.example.com","latency_ms":45}
    #
    class Ping
      # Registers the ping command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Check connectivity to Proxmox cluster"
        cli.command :ping do |c|
          c.action do |global_options, _options, _args|
            exit_code = execute(global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the ping command.
      #
      # @param global_options [Hash] global CLI options
      #   - :config [String, nil] path to config file
      #   - :output [String] output format (table, wide, json, yaml)
      #   - :color [Boolean, nil] explicit color flag
      # @return [Integer] exit code (0 for success, 4 for connection error)
      def self.execute(global_options)
        new(global_options).execute
      end

      # Creates a new Ping command instance.
      #
      # @param global_options [Hash] global CLI options
      def initialize(global_options)
        @global_options = global_options
        @output_format = global_options[:output] || "table"
        @color_flag = global_options[:color]
        @config = nil
      end

      # Executes the ping operation.
      #
      # @return [Integer] exit code
      def execute
        load_config
        connection = Pvectl::Connection.new(@config)

        result = measure_ping(connection)
        output_result(result, @config.server)

        ExitCodes::SUCCESS
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError => e
        # Re-raise config errors to be handled by CLI error handler
        raise
      rescue Timeout::Error
        output_error("Connection timed out", server_url)
        ExitCodes::CONNECTION_ERROR
      rescue Errno::ECONNREFUSED
        output_error("Connection refused", server_url)
        ExitCodes::CONNECTION_ERROR
      rescue SocketError => e
        output_error(e.message, server_url)
        ExitCodes::CONNECTION_ERROR
      rescue StandardError => e
        output_error(e.message, server_url)
        ExitCodes::CONNECTION_ERROR
      end

      private

      attr_reader :global_options, :output_format, :color_flag

      # Loads configuration from service.
      #
      # @return [Config::Models::ResolvedConfig] the resolved configuration
      # @raise [Config::ConfigNotFoundError] if config not found
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: global_options[:config])
        @config = service.current_config
      end

      # Returns the server URL, or "unknown" if config not loaded.
      #
      # @return [String] server URL or "unknown"
      def server_url
        @config&.server || "unknown"
      end

      # Measures ping latency by timing the version API call.
      #
      # @param connection [Connection] the connection to use
      # @return [Hash] result with :latency_ms
      def measure_ping(connection)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        connection.version
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        {
          latency_ms: ((end_time - start_time) * 1000).round
        }
      end

      # Outputs the result based on the selected format.
      #
      # @param result [Hash] the ping result
      # @param server [String] the server URL
      # @return [void]
      def output_result(result, server)
        case output_format
        when "json"
          output_json(result, server)
        when "yaml"
          output_yaml(result, server)
        when "wide"
          output_wide(result, server)
        else
          output_simple(server)
        end
      end

      # Outputs simple text format.
      #
      # @param server [String] the server URL
      # @return [void]
      def output_simple(server)
        pastel = Formatters::ColorSupport.pastel(explicit_flag: color_flag)
        puts "#{pastel.green('OK')} - Connected to #{extract_host(server)}"
      end

      # Outputs wide text format with latency.
      #
      # @param result [Hash] the ping result
      # @param server [String] the server URL
      # @return [void]
      def output_wide(result, server)
        pastel = Formatters::ColorSupport.pastel(explicit_flag: color_flag)
        puts "#{pastel.green('OK')} - Connected to #{extract_host(server)} | " \
             "Latency: #{result[:latency_ms]}ms"
      end

      # Outputs JSON format.
      #
      # @param result [Hash] the ping result
      # @param server [String] the server URL
      # @return [void]
      def output_json(result, server)
        require "json"
        puts JSON.pretty_generate({
          status: "ok",
          server: extract_host(server),
          latency_ms: result[:latency_ms]
        })
      end

      # Outputs YAML format.
      #
      # @param result [Hash] the ping result
      # @param server [String] the server URL
      # @return [void]
      def output_yaml(result, server)
        require "yaml"
        puts YAML.dump({
          "status" => "ok",
          "server" => extract_host(server),
          "latency_ms" => result[:latency_ms]
        })
      end

      # Outputs error message.
      #
      # @param message [String] the error message
      # @param server [String] the server URL
      # @return [void]
      def output_error(message, server)
        pastel = Formatters::ColorSupport.pastel(explicit_flag: color_flag)
        host = extract_host(server)

        case output_format
        when "json"
          require "json"
          puts JSON.pretty_generate({ status: "error", server: host, error: message })
        when "yaml"
          require "yaml"
          puts YAML.dump({ "status" => "error", "server" => host, "error" => message })
        else
          $stderr.puts "#{pastel.red('ERROR')} - Cannot connect to #{host}: #{message}"
        end
      end

      # Extracts hostname from server URL.
      #
      # @param server_url [String] the full server URL
      # @return [String] the hostname
      def extract_host(server_url)
        uri = URI.parse(server_url)
        uri.host
      rescue StandardError
        server_url
      end
    end
  end
end
