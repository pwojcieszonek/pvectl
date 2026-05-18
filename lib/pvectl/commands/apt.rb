# frozen_string_literal: true

module Pvectl
  module Commands
    # Top-level `pvectl apt` command for managing APT packages on Proxmox nodes.
    #
    # Exposes four sub-commands:
    #
    # * `apt list`      list pending package updates
    # * `apt update`    refresh the package index (apt-get update)
    # * `apt changelog` show changelog for a package
    # * `apt versions`  list installed Proxmox-relevant package versions
    #
    # Each sub-command requires `--node NODE` (falls back to default-node from
    # the active context configuration when not provided).
    #
    # @example Register with the CLI
    #   Commands::Apt.register(cli)
    #
    class Apt
      # Registers the apt command and all sub-commands with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Manage APT packages on Proxmox nodes"
        cli.long_desc <<~HELP
          DESCRIPTION
            Manage APT (Advanced Package Tool) packages on Proxmox VE nodes.
            Wraps the Proxmox /nodes/{node}/apt API to inspect pending updates,
            refresh the package index, read package changelogs, and report
            installed Proxmox-relevant package versions.

          SUB-COMMANDS
            apt list                 List pending package updates
            apt update               Refresh the package index (apt-get update)
            apt changelog PACKAGE    Show changelog for a package
            apt versions             Show installed Proxmox package versions

          EXAMPLES
            List pending updates on a node:
              $ pvectl apt list --node pve1

            Refresh the package index on the default node:
              $ pvectl apt update

            Refresh quietly without sending update notifications:
              $ pvectl apt update --node pve1 --quiet

            Show changelog for a specific package version:
              $ pvectl apt changelog pve-manager --node pve1 --version 8.2.4-1

            Inspect installed Proxmox versions (parity with pveversion -v):
              $ pvectl apt versions --node pve1 -o wide

          NOTES
            --node defaults to the context's default-node when configured.

            Proxmox does NOT expose `apt upgrade` over the API (security
            restriction). To actually install updates you must SSH to the
            node and run apt full-upgrade manually.

            `apt update` is asynchronous; the response includes the Proxmox
            task UPID, inspect with `pvectl get tasks` and
            `pvectl logs task UPID`.

          SEE ALSO
            pvectl help get             List resources (try `get nodes`)
            pvectl help logs            Inspect task output
        HELP

        cli.command :apt do |c|
          # Shared --node flag declared on the parent so every subcommand inherits it.
          c.desc "Node name (defaults to context default-node)"
          c.flag [:node], arg_name: "NODE"

          register_list(c)
          register_update(c)
          register_changelog(c)
          register_versions(c)
        end
      end

      # Registers the `apt list` subcommand.
      #
      # @param parent [GLI::Command] parent apt command
      # @return [void]
      def self.register_list(parent)
        parent.desc "List pending APT updates on a node"
        parent.long_desc <<~HELP
          List packages that have an available APT update on the target node.

          EXAMPLES
            $ pvectl apt list --node pve1
            $ pvectl apt list --node pve1 -o wide
            $ pvectl apt list --node pve1 -o json

          SEE ALSO
            pvectl help apt          Parent command
        HELP
        parent.command :list do |sub|
          sub.action do |global_options, options, args|
            exit_code = execute(:list, args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Registers the `apt update` subcommand.
      #
      # @param parent [GLI::Command] parent apt command
      # @return [void]
      def self.register_update(parent)
        parent.desc "Refresh the APT package index on a node (apt-get update)"
        parent.long_desc <<~HELP
          Refresh the APT package index on the target node. Equivalent to
          running `apt-get update` directly on the node.

          This does NOT install updates — Proxmox does not expose apt upgrade
          over the API for security reasons.

          EXAMPLES
            $ pvectl apt update --node pve1
            $ pvectl apt update --node pve1 --quiet
            $ pvectl apt update --node pve1 --notify

          SEE ALSO
            pvectl help apt          Parent command
        HELP
        parent.command :update do |sub|
          sub.desc "Send a notification about new packages"
          sub.switch [:notify], negatable: false

          sub.desc "Suppress progress output"
          sub.switch [:quiet], negatable: false

          sub.action do |global_options, options, args|
            exit_code = execute(:update, args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Registers the `apt changelog` subcommand.
      #
      # @param parent [GLI::Command] parent apt command
      # @return [void]
      def self.register_changelog(parent)
        parent.desc "Show the changelog for an APT package on a node"
        parent.long_desc <<~HELP
          Show the upstream changelog for a package on the target node. When
          --version is omitted the latest available version's changelog is
          returned.

          EXAMPLES
            $ pvectl apt changelog pve-manager --node pve1
            $ pvectl apt changelog pve-manager --node pve1 --version 8.2.4-1

          SEE ALSO
            pvectl help apt          Parent command
        HELP
        parent.arg_name "PACKAGE"
        parent.command :changelog do |sub|
          sub.desc "Package version (optional, defaults to latest)"
          sub.flag [:version], arg_name: "VERSION"

          sub.action do |global_options, options, args|
            exit_code = execute(:changelog, args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Registers the `apt versions` subcommand.
      #
      # @param parent [GLI::Command] parent apt command
      # @return [void]
      def self.register_versions(parent)
        parent.desc "Show installed Proxmox package versions on a node"
        parent.long_desc <<~HELP
          Show installed versions of important Proxmox VE packages on the
          target node — parity with `pveversion -v` on the node itself.

          EXAMPLES
            $ pvectl apt versions --node pve1
            $ pvectl apt versions --node pve1 -o wide
            $ pvectl apt versions --node pve1 -o yaml

          SEE ALSO
            pvectl help apt          Parent command
        HELP
        parent.command :versions do |sub|
          sub.action do |global_options, options, args|
            exit_code = execute(:versions, args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the command.
      #
      # @param operation [Symbol] :list, :update, :changelog, :versions
      # @param args [Array<String>] positional CLI arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(operation, args, options, global_options)
        new(operation, args, options, global_options).execute
      end

      # Initializes an apt command instance.
      #
      # @param operation [Symbol] operation
      # @param args [Array<String>] positional CLI arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @param output [IO] IO for output (default: $stdout)
      def initialize(operation, args, options, global_options, output: $stdout)
        @operation = operation
        @args = Array(args).compact
        @options = options
        @global_options = global_options
        @output = output
      end

      # Executes the command.
      #
      # @return [Integer] exit code
      def execute
        load_config
        node = resolve_node
        return config_error("node is required (provide --node or configure default-node)") unless node

        case @operation
        when :list      then run_list(node)
        when :update    then run_update(node)
        when :changelog then run_changelog(node)
        when :versions  then run_versions(node)
        else
          usage_error("Unknown apt operation: #{@operation}")
        end
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

      # Returns the apt repository (lazy).
      #
      # @return [Repositories::Apt] APT repository
      def repository
        @repository ||= Pvectl::Repositories::Apt.new(Pvectl::Connection.new(@config))
      end

      # Runs `apt list` — prints pending updates as a table.
      #
      # @param node [String] node name
      # @return [Integer] exit code
      def run_list(node)
        packages = repository.pending(node)
        render_packages(packages)
        ExitCodes::SUCCESS
      end

      # Runs `apt update` — triggers index refresh and reports the UPID.
      #
      # @param node [String] node name
      # @return [Integer] exit code
      def run_update(node)
        upid = repository.refresh(node, notify: @options[:notify] ? true : false,
                                        quiet: @options[:quiet] ? true : false)
        result = build_update_result(node, upid)
        render_operation_result(result)
        ExitCodes::SUCCESS
      end

      # Runs `apt changelog` — prints raw changelog text to stdout.
      #
      # @param node [String] node name
      # @return [Integer] exit code
      def run_changelog(node)
        return usage_error("package name is required") if @args.empty?

        package = @args.first
        version = @options[:version]
        text = repository.changelog(node, package, version: version)
        if text.nil? || text.empty?
          @output.puts "(no changelog available)"
        else
          @output.puts text
        end
        ExitCodes::SUCCESS
      end

      # Runs `apt versions` — lists important Proxmox package versions.
      #
      # @param node [String] node name
      # @return [Integer] exit code
      def run_versions(node)
        packages = repository.versions(node)
        render_packages(packages)
        ExitCodes::SUCCESS
      end

      # Renders an array of AptPackage models using the configured formatter.
      #
      # @param packages [Array<Models::AptPackage>] packages
      # @return [void]
      def render_packages(packages)
        Pvectl::Formatters::OutputHelper.print(
          data: packages,
          presenter: Pvectl::Presenters::AptPackage.new,
          format: @global_options[:output] || "table",
          color_flag: @global_options[:color]
        )
      end

      # Renders a NodeOperationResult (used by `apt update`).
      #
      # @param result [Models::NodeOperationResult] operation result
      # @return [void]
      def render_operation_result(result)
        Pvectl::Formatters::OutputHelper.print(
          data: [result],
          presenter: Pvectl::Presenters::NodeOperationResult.new,
          format: @global_options[:output] || "table",
          color_flag: @global_options[:color]
        )
      end

      # Builds a NodeOperationResult representing an apt update kick-off.
      #
      # @param node [String] node name
      # @param upid [String] task UPID returned by the API
      # @return [Models::NodeOperationResult]
      def build_update_result(node, upid)
        Pvectl::Models::NodeOperationResult.new(
          operation: :update,
          node_model: Pvectl::Models::Node.new(name: node),
          resource: { node: node },
          task_upid: upid,
          success: :pending
        )
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
