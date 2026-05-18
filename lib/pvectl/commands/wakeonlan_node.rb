# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl wakeonlan node` command.
    #
    # Sends a Wake-on-LAN magic packet to a cluster node. The target node
    # must have its MAC address registered in the cluster configuration
    # (via `pvecm` or the web UI) — without it, Proxmox cannot assemble
    # the packet and the command returns an error.
    #
    # The Proxmox API returns the MAC address used for the packet on
    # success, which is surfaced in the output for confirmation.
    #
    # @example Wake up a node
    #   pvectl wakeonlan node pve3
    #
    # @example JSON output for scripting
    #   pvectl wakeonlan node pve3 -o json
    #
    class WakeonlanNode
      # Registers the `wakeonlan node` command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Send Wake-on-LAN packet to a cluster node"
        cli.long_desc <<~HELP
          Trigger a Wake-on-LAN magic packet to a cluster node via the
          Proxmox API (POST /nodes/{node}/wakeonlan).

          EXAMPLES
            Wake a node:
              $ pvectl wakeonlan node pve3

            Output as JSON:
              $ pvectl wakeonlan node pve3 -o json

          NOTES
            The target node must have its MAC address registered in the
            cluster configuration beforehand. Use `pvecm` or the Proxmox
            web UI to set the MAC for each node before relying on WoL.

            The packet is sent by another online node in the cluster, so
            at least one other node must be reachable.

          SEE ALSO
            pvectl help get nodes      List nodes and current status
            pvectl help describe node  Show node details
        HELP
        cli.arg_name "RESOURCE_TYPE NAME"
        cli.command :wakeonlan do |c|
          c.action do |global_options, _options, args|
            resource_type = args.shift
            resource_name = args.shift

            unless resource_type == "node"
              $stderr.puts "Error: Only `pvectl wakeonlan node <NAME>` is supported"
              exit Pvectl::ExitCodes::USAGE_ERROR
            end

            cmd = WakeonlanNode.new(resource_name, {}, global_options)
            exit_code = cmd.execute
            exit exit_code if exit_code != 0
          end
        end
      end

      # Creates a new command instance.
      #
      # @param node_name [String, nil] target node name
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @param service [Services::Wakeonlan, nil] injected service (testing)
      def initialize(node_name, options, global_options, service: nil)
        @node_name = node_name
        @options = options
        @global_options = global_options
        @service = service
      end

      # Executes the wakeonlan command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("NODE name is required") if @node_name.nil? || @node_name.to_s.empty?

        result = service.execute(node_name: @node_name)
        render(result)

        result.successful? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::CONNECTION_ERROR
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      private

      # Lazily builds the Wakeonlan service from current config.
      #
      # @return [Services::Wakeonlan]
      def service
        @service ||= begin
          config_service = Pvectl::Config::Service.new
          config_service.load(config: @global_options[:config])
          connection = Pvectl::Connection.new(config_service.current_config)
          node_repo = Pvectl::Repositories::Node.new(connection)
          Pvectl::Services::Wakeonlan.new(node_repository: node_repo)
        end
      end

      # Renders the operation result using the requested output format.
      #
      # @param result [Models::NodeOperationResult]
      # @return [void]
      def render(result)
        format = @global_options[:output] || "table"
        presenter = Pvectl::Presenters::NodeOperationResult.new
        formatter = Pvectl::Formatters::Registry.for(format)
        puts formatter.format([result], presenter, color_enabled: color_enabled)
      end

      # Determines color output based on global flag and TTY status.
      #
      # @return [Boolean]
      def color_enabled
        explicit = @global_options[:color]
        return explicit unless explicit.nil?

        $stdout.tty?
      end

      # Outputs a usage error and returns the proper exit code.
      #
      # @param msg [String]
      # @return [Integer]
      def usage_error(msg)
        $stderr.puts "Error: #{msg}"
        $stderr.puts "Usage: pvectl wakeonlan node <NODE>"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
