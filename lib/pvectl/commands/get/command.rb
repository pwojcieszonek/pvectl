# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      # Dispatcher for the `pvectl get <resource_type>` command.
      #
      # Routes requests to appropriate resource handlers based on the
      # resource type argument. Supports watch mode for continuous
      # monitoring and node filtering.
      #
      # Responsibilities:
      # - Control flow (watch vs single execution)
      # - Handler lookup via ResourceRegistry
      # - Error handling for unknown resources and handler exceptions
      #
      # Delegates to:
      # - Services::Get::ResourceService for data fetching and formatting
      #
      # @example Basic usage
      #   Commands::Get::Command.execute("nodes", nil, options, global_options)
      #
      # @example With watch mode
      #   options = { watch: true, :"watch-interval" => 5 }
      #   Commands::Get::Command.execute("vms", nil, options, global_options)
      #
      class Command
        # Registers the get command with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "List resources in cluster"
          cli.long_desc <<~HELP
            List resources across the Proxmox cluster. Supports multiple resource
            types including nodes, VMs, containers, storage, snapshots, backups,
            templates, and tasks.

            Results can be filtered by node (--node), formatted in different output
            modes (-o), and auto-refreshed with watch mode (-w).

            RESOURCE TYPES
              nodes (node)              Cluster nodes
              vms (vm)                  Virtual machines
              containers (ct, cts)      LXC containers
              storage (stor)            Storage pools
              snapshots (snap)          VM/CT snapshots
              backups (backup)          Backup volumes
              templates (template)      VM and container templates
              tasks (task)              Task history

            EXAMPLES
              List all VMs in table format:
                $ pvectl get vms

              List containers on a specific node as JSON:
                $ pvectl get containers --node pve1 -o json

              List snapshots for specific VMs:
                $ pvectl get snapshots --vmid 100 --vmid 101

              Watch cluster nodes with 5-second refresh:
                $ pvectl get nodes -w --watch-interval 5

              Filter tasks by type and date:
                $ pvectl get tasks --type vzdump --since 2026-01-01

              Wide output with extra columns:
                $ pvectl get vms -o wide

              Filter VMs by status using selectors:
                $ pvectl get vms -l status=running

            NOTES
              Use selectors (-l) to filter VMs/containers by status, name, tags, or
              pool. Multiple selectors use AND logic.

              Task listing defaults to 50 entries; use --limit to change.

              Watch mode clears the screen on each refresh. Press Ctrl+C to stop.

            SEE ALSO
              pvectl help describe    Show detailed info about a single resource
              pvectl help top         Display real-time resource usage metrics
              pvectl help logs        Show logs and task history
          HELP
          cli.command :get do |c|
            c.desc "Filter by node name"
            c.flag [:node], arg_name: "NODE"

            c.desc "Filter by VM/CT ID (repeatable)"
            c.flag [:vmid], arg_name: "VMID", multiple: true

            c.desc "Filter by storage (for backups)"
            c.flag [:storage], arg_name: "STORAGE"

            c.desc "Watch for changes with auto-refresh"
            c.switch [:watch, :w], negatable: false

            c.desc "Watch refresh interval in seconds (default: 2, minimum: 1)"
            c.default_value 2
            c.flag [:"watch-interval"], arg_name: "SECONDS", type: Integer

            c.desc "Maximum number of entries to show (for tasks)"
            c.default_value 50
            c.flag [:limit], type: Integer, arg_name: "N"

            c.desc "Show entries since timestamp (YYYY-MM-DD or epoch, for tasks)"
            c.flag [:since], arg_name: "TIMESTAMP"

            c.desc "Show entries until timestamp (YYYY-MM-DD or epoch, for tasks)"
            c.flag [:until], arg_name: "TIMESTAMP"

            c.desc "Filter by task type (e.g., qmstart, qmstop, vzdump)"
            c.flag [:type], arg_name: "TYPE"

            c.desc "Filter by status (running, ok, error)"
            c.flag [:status], arg_name: "STATUS"

            c.desc "Search across all cluster nodes (default for tasks)"
            c.switch [:"all-nodes"], negatable: false

            c.action do |global_options, options, args|
              resource_type = args[0]
              resource_args = args[1..] || []
              exit_code = execute(resource_type, resource_args, options, global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the get command.
        #
        # @param resource_type [String, nil] type of resource to list (e.g., "nodes", "vms")
        # @param args [String, Array, nil] positional arguments (VMIDs for snapshots, or name filter)
        # @param options [Hash] command-specific options
        #   - :watch [Boolean] enable continuous monitoring
        #   - :"watch-interval" [Integer] refresh interval in seconds
        #   - :node [String] filter by node name
        # @param global_options [Hash] global CLI options
        #   - :output [String] output format (table, json, yaml, wide)
        #   - :color [Boolean, nil] explicit color setting
        # @return [Integer] exit code (0 for success, 2 for unknown resource)
        def self.execute(resource_type, args, options, global_options)
          new(resource_type, args, options, global_options).execute
        end

        # Creates a new Get command instance.
        #
        # @param resource_type [String, nil] type of resource to list
        # @param args [String, Array, nil] positional arguments
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @param registry [Class] registry class for dependency injection (default: ResourceRegistry)
        def initialize(resource_type, args, options, global_options,
                       registry: ResourceRegistry)
          @resource_type = resource_type
          @args = normalize_args(args)
          @options = options
          @global_options = global_options
          @registry = registry
        end

        # Executes the get operation.
        #
        # @return [Integer] exit code
        def execute
          return missing_resource_type_error if @resource_type.nil?

          handler = @registry.for(@resource_type)
          return unknown_resource_error unless handler

          if @options[:watch]
            run_watch_mode(handler)
          else
            run_once(handler)
          end

          ExitCodes::SUCCESS
        rescue Timeout::Error => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        rescue Errno::ECONNREFUSED => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        rescue SocketError => e
          output_connection_error(e.message)
          ExitCodes::CONNECTION_ERROR
        rescue ArgumentError => e
          output_usage_error(e.message)
          ExitCodes::USAGE_ERROR
        end

        private

        attr_reader :resource_type, :args, :options, :global_options

        # Normalizes args to an array.
        #
        # @param args [String, Array, nil] input args
        # @return [Array<String>] normalized args array
        def normalize_args(args)
          case args
          when nil then []
          when Array then args
          else [args.to_s]
          end
        end

        # Outputs error for missing resource type argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_type_error
          $stderr.puts "Error: resource type is required"
          $stderr.puts "Usage: pvectl get RESOURCE_TYPE [NAME] [options]"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for unknown resource type.
        #
        # @return [Integer] USAGE_ERROR exit code
        def unknown_resource_error
          $stderr.puts "Unknown resource type: #{@resource_type}"
          ExitCodes::USAGE_ERROR
        end

        # Outputs connection error message.
        #
        # @param message [String] the error message
        # @return [void]
        def output_connection_error(message)
          $stderr.puts "Error: #{message}"
        end

        # Outputs usage error message.
        #
        # @param message [String] the error message
        # @return [void]
        def output_usage_error(message)
          $stderr.puts "Error: #{message}"
        end

        # Executes a single fetch and display operation.
        #
        # @param handler [ResourceHandler] the resource handler
        # @return [void]
        def run_once(handler)
          service = build_service(handler)
          output = service.list(
            node: options[:node],
            name: nil,
            args: args,
            storage: options[:storage],
            vmid: options[:vmid],
            limit: options[:limit],
            since: options[:since],
            until_time: options[:until],
            type_filter: options[:type],
            status_filter: options[:status],
            all_nodes: options[:"all-nodes"] || false
          )
          puts output
        end

        # Executes watch mode with continuous refresh.
        #
        # @param handler [ResourceHandler] the resource handler
        # @return [void]
        def run_watch_mode(handler)
          interval = options[:"watch-interval"] || WatchLoop::DEFAULT_INTERVAL
          watch_loop = WatchLoop.new(interval: interval)
          watch_loop.run { run_once(handler) }
        end

        # Builds the service for the given handler.
        #
        # @param handler [ResourceHandler] the resource handler
        # @return [Services::Get::ResourceService] the service instance
        def build_service(handler)
          Services::Get::ResourceService.new(
            handler: handler,
            format: global_options[:output] || "table",
            color_enabled: determine_color_enabled
          )
        end

        # Determines if color output should be enabled.
        #
        # @return [Boolean] true if color should be enabled
        def determine_color_enabled
          explicit = global_options[:color]
          return explicit unless explicit.nil?

          $stdout.tty?
        end
      end
    end
  end
end
