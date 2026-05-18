# frozen_string_literal: true

module Pvectl
  module Commands
    # Top-level `pvectl service` command for managing systemd services on
    # Proxmox nodes.
    #
    # Exposes four lifecycle sub-commands:
    #
    # * `service start <name>`   start a service
    # * `service stop <name>`    stop a service (irreversible — requires --yes or prompt)
    # * `service restart <name>` hard restart a service (irreversible — requires --yes or prompt)
    # * `service reload <name>`  reload (graceful where supported)
    #
    # Each sub-command requires `--node NODE` (falls back to default-node from
    # the active context configuration when not provided).
    #
    # @example Register with the CLI
    #   Commands::Service.register(cli)
    #
    class Service
      # All confirmable operations (stop and restart can disrupt running workloads).
      CONFIRMABLE_OPERATIONS = %i[stop restart].freeze

      # All supported operations.
      OPERATIONS = %i[start stop restart reload].freeze

      # Registers the service command and all sub-commands with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Manage systemd services on Proxmox nodes"
        cli.long_desc <<~HELP
          Manage systemd services running on Proxmox VE nodes. Wraps the Proxmox
          /nodes/{node}/services API to start, stop, restart, or reload daemons
          such as pveproxy, pvedaemon, corosync, and others.

          SUB-COMMANDS
            service start NAME      Start a stopped service
            service stop NAME       Stop a running service (irreversible)
            service restart NAME    Hard restart a service (irreversible)
            service reload NAME     Reload a service (graceful where supported)

          EXAMPLES
            Restart the API proxy on a single node (with confirmation skipped):
              $ pvectl service restart pveproxy --node pve1 --yes

            Start a stopped service on the default node:
              $ pvectl service start cron

            Stop a service after interactive confirmation:
              $ pvectl service stop pve-firewall --node pve1

            Reload the syslog daemon (no interruption to running workloads):
              $ pvectl service reload syslog --node pve1

          NOTES
            --node defaults to the context's default-node if configured.

            stop and restart are irreversible and require either an interactive
            "yes" confirmation or the --yes flag to skip the prompt.

            Restarting pveproxy or corosync can momentarily disconnect the
            current API session and break cluster membership respectively. Use
            --yes only when you understand the impact.

            Operations are asynchronous — the result includes the Proxmox task
            UPID which can be inspected with `pvectl get tasks` and
            `pvectl logs task UPID`.

          SEE ALSO
            pvectl help get             List resources (try `get services`)
            pvectl help logs            Inspect task output
        HELP
        cli.command :service do |c|
          # Shared flags declared on the parent so all subcommands inherit them.
          # Avoids GLI flag-redefinition errors when the same flag is needed by
          # multiple sibling subcommands (e.g. start/stop/restart/reload all
          # need --node and --yes).
          c.desc "Node name (defaults to context default-node)"
          c.flag [:node], arg_name: "NODE"

          c.desc "Skip interactive confirmation prompt"
          c.switch [:yes, :y], negatable: false

          OPERATIONS.each do |op|
            register_subcommand(c, op)
          end
        end
      end

      # Registers a single lifecycle sub-command.
      #
      # @param parent [GLI::Command] parent service command
      # @param operation [Symbol] one of :start, :stop, :restart, :reload
      # @return [void]
      def self.register_subcommand(parent, operation)
        parent.desc "#{operation.capitalize} a systemd service on a Proxmox node"
        parent.long_desc subcommand_long_desc(operation)
        parent.arg_name "SERVICE_NAME"
        parent.command operation do |sub|
          sub.action do |global_options, options, args|
            exit_code = execute(operation, args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Builds the man-page-style long_desc for a sub-command.
      #
      # @param operation [Symbol] operation
      # @return [String] long help text
      def self.subcommand_long_desc(operation)
        action = operation.to_s
        confirm_note =
          if CONFIRMABLE_OPERATIONS.include?(operation)
            "This operation is irreversible. Without --yes, pvectl will\n  prompt for interactive confirmation before contacting the API."
          else
            "No confirmation is required for this operation."
          end

        <<~HELP
          #{action.capitalize} a systemd service on a Proxmox node.

          EXAMPLES
            $ pvectl service #{action} pveproxy --node pve1
            $ pvectl service #{action} pveproxy --node pve1 --yes

          NOTES
            #{confirm_note}

            Restarting pveproxy or corosync can momentarily disconnect the
            current API session and break cluster membership respectively.

            --node defaults to the context's default-node.

          SEE ALSO
            pvectl help service     Parent command
            pvectl help get         List resources (try `get services`)
        HELP
      end

      # Executes the command.
      #
      # @param operation [Symbol] operation (:start, :stop, :restart, :reload)
      # @param args [Array<String>] positional CLI arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(operation, args, options, global_options)
        new(operation, args, options, global_options).execute
      end

      # Initializes a service lifecycle command.
      #
      # @param operation [Symbol] operation
      # @param args [Array<String>] positional CLI arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @param prompt [IO] IO for confirmation prompts (default: $stdin)
      # @param output [IO] IO for output (default: $stdout)
      def initialize(operation, args, options, global_options, prompt: $stdin, output: $stdout)
        @operation = operation
        @args = Array(args).compact
        @options = options
        @global_options = global_options
        @prompt = prompt
        @output = output
      end

      # Executes the command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("service name is required") if @args.empty?

        service_name = @args.first
        load_config
        node = resolve_node
        return config_error("node is required (provide --node or configure default-node)") unless node

        return ExitCodes::SUCCESS unless confirm!(service_name, node)

        result = perform(service_name, node)
        output_result(result)
        result.failed? ? ExitCodes::GENERAL_ERROR : ExitCodes::SUCCESS
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::CONFIG_ERROR
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      private

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Resolves the node from --node option or default-node config.
      #
      # @return [String, nil] node name or nil if unresolvable
      def resolve_node
        @options[:node] || @config&.default_node
      end

      # Confirms the operation when required.
      #
      # @param service_name [String] service identifier
      # @param node [String] node name
      # @return [Boolean] true if operation should proceed
      def confirm!(service_name, node)
        return true unless CONFIRMABLE_OPERATIONS.include?(@operation)
        return true if @options[:yes]

        warning = service_warning(service_name)
        @output.puts "About to #{@operation} service '#{service_name}' on node '#{node}'."
        @output.puts warning if warning
        @output.print "Continue? [y/N] "
        answer = @prompt.gets&.strip&.downcase
        confirmed = %w[y yes].include?(answer)
        @output.puts "Aborted." unless confirmed
        confirmed
      end

      # Returns a warning string for sensitive services, or nil.
      #
      # @param service_name [String] service identifier
      # @return [String, nil] warning
      def service_warning(service_name)
        case service_name
        when "pveproxy", "pvedaemon"
          "Warning: this may disconnect the current API session."
        when "corosync", "pve-cluster"
          "Warning: this can disrupt cluster membership and quorum."
        end
      end

      # Performs the API call via ServiceLifecycle.
      #
      # @param service_name [String] service identifier
      # @param node [String] node name
      # @return [Models::NodeOperationResult]
      def perform(service_name, node)
        connection = Pvectl::Connection.new(@config)
        repository = Pvectl::Repositories::Service.new(connection)
        lifecycle = Pvectl::Services::ServiceLifecycle.new(service_repository: repository)
        lifecycle.execute(operation: @operation, node: node, service: service_name)
      end

      # Outputs the operation result using the configured formatter.
      #
      # @param result [Models::NodeOperationResult]
      # @return [void]
      def output_result(result)
        format = @global_options[:output] || "table"
        color = @global_options[:color]
        formatter = Pvectl::Formatters::Registry.for(format)
        presenter = Pvectl::Presenters::NodeOperationResult.new
        @output.puts formatter.format([result], presenter, color: color)
      end

      # Outputs a usage error.
      #
      # @param message [String] error message
      # @return [Integer] USAGE_ERROR exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end

      # Outputs a config error.
      #
      # @param message [String] error message
      # @return [Integer] CONFIG_ERROR exit code
      def config_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::CONFIG_ERROR
      end
    end
  end
end
