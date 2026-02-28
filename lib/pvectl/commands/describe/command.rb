# frozen_string_literal: true

module Pvectl
  module Commands
    module Describe
      # Dispatcher for the `pvectl describe <resource_type> <name>` command.
      #
      # Uses EXISTING Get infrastructure:
      # - Commands::Get::ResourceRegistry for handler lookup
      # - Services::Get::ResourceService for orchestration
      # - Handlers call describe() instead of list()
      #
      # @example Basic usage
      #   Commands::Describe::Command.execute("node", "pve1", options, global_options)
      #
      class Command
        # Registers the describe command with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "Show detailed information about a resource"
          cli.long_desc <<~HELP
            Show detailed information about a specific resource. Displays all
            configuration details, runtime status, and related resources in
            structured, labeled sections.

            Unlike 'get' which lists many resources in a table, 'describe' shows
            everything known about a single resource in a readable format.
            Unknown or future Proxmox config keys appear in an "Additional
            Configuration" catch-all section, so new API fields are never hidden.

            RESOURCE TYPES
              node NAME                 Full node diagnostics (CPU, memory, storage, services)
              vm VMID                   Comprehensive VM configuration (see VM SECTIONS below)
              container VMID            Comprehensive container configuration (see CT SECTIONS below)
              storage NAME              Storage pool info, content types, usage
              snapshot NAME             Snapshot metadata and snapshot tree (use --vmid)
              volume TYPE ID DISK       Virtual disk details (e.g., describe volume vm 100 scsi0)

            VM SECTIONS (matches PVE web UI tabs)
              Summary        HA state, CPU/memory usage, bootdisk size, uptime,
                             QEMU version, machine type, network/disk I/O
              Hardware       Memory, balloon, processors, BIOS, machine, display,
                             SCSI controller, EFI/TPM, disks, network, USB/PCI,
                             serial ports, audio
              Cloud-Init     Type, user, DNS, SSH keys, IP config
              Options        Start at boot, startup order, OS type, boot order,
                             tablet, hotplug, ACPI, KVM, freeze, localtime,
                             NUMA, QEMU guest agent, protection, firewall,
                             hookscript
              Task History   Recent operations (type, status, date, duration, user)
              Snapshots      Name, date, VM state, description
              Pending        Configuration changes awaiting reboot
              Additional     Catch-all for unrecognized config keys

            CT SECTIONS (matches PVE web UI tabs)
              Summary        CPU/memory/swap/rootfs usage, uptime, PID, network I/O
              Resources      Memory, swap, cores, root filesystem, mountpoints
              Network        Interfaces with bridge, IP, MAC
              DNS            Nameserver, search domain
              Options        Start at boot, startup order, OS type, architecture,
                             unprivileged, features, console mode, TTY, protection,
                             hookscript
              Task History   Recent operations (type, status, date, duration, user)
              Snapshots      Name, date, description
              High Avail.    HA state and group
              Additional     Catch-all for unrecognized config keys

            EXAMPLES
              Full node diagnostics:
                $ pvectl describe node pve1

              VM details — all configuration sections:
                $ pvectl describe vm 100

              Container details — all configuration sections:
                $ pvectl describe container 200

              Storage pool information (node-specific):
                $ pvectl describe storage local-lvm --node pve1

              Snapshot metadata for a specific VM:
                $ pvectl describe snapshot before-upgrade --vmid 100

              Snapshot search across multiple VMs:
                $ pvectl describe snapshot before-upgrade --vmid 100 --vmid 101

              Snapshot search cluster-wide (all VMs and containers):
                $ pvectl describe snapshot before-upgrade

              Virtual disk details:
                $ pvectl describe volume vm 100 scsi0

              Container rootfs:
                $ pvectl describe volume ct 200 rootfs

            NOTES
              For local storage, --node is required because local storage exists
              independently on each node.

              Snapshot describe shows a visual tree of all snapshots for the
              matching VMs, highlighting the described snapshot.

              VM and container describe output includes ALL configuration from
              the Proxmox API. Any fields not recognized by the presenter are
              grouped in the "Additional Configuration" section at the end.

            SEE ALSO
              pvectl help get           List resources in table format
              pvectl help get volume    List virtual disks attached to VMs/containers
              pvectl help logs          Show task history and logs
          HELP
          cli.arg_name "RESOURCE_TYPE NAME"
          cli.command :describe do |c|
            c.desc "Filter by node name (required for local storage)"
            c.flag [:node], arg_name: "NODE"

            c.desc "Filter by VM/CT ID (repeatable)"
            c.flag [:vmid], arg_name: "VMID", multiple: true

            c.action do |global_options, options, args|
              resource_type = args[0]
              resource_name = args[1]
              extra_args = args[2..] || []
              exit_code = execute(resource_type, resource_name, options, global_options, extra_args: extra_args)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the describe command.
        #
        # @param resource_type [String, nil] type of resource (e.g., "node")
        # @param resource_name [String, nil] name of resource to describe
        # @param options [Hash] command-specific options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(resource_type, resource_name, options, global_options, extra_args: [])
          new(resource_type, resource_name, options, global_options, extra_args: extra_args).execute
        end

        # Creates a new Describe command instance.
        #
        # @param resource_type [String, nil] type of resource
        # @param resource_name [String, nil] name of resource to describe
        # @param options [Hash] command options
        # @param global_options [Hash] global CLI options
        # @param registry [Class] registry class for dependency injection
        def initialize(resource_type, resource_name, options, global_options,
                       extra_args: [], registry: Get::ResourceRegistry)
          @resource_type = resource_type
          @resource_name = resource_name
          @options = options
          @global_options = global_options
          @extra_args = extra_args
          @registry = registry
        end

        # Executes the describe operation.
        #
        # @return [Integer] exit code
        def execute
          return missing_resource_type_error if @resource_type.nil?
          return missing_resource_name_error if @resource_name.nil?

          handler = @registry.for(@resource_type)
          return unknown_resource_error unless handler

          run_describe(handler)
          ExitCodes::SUCCESS
        rescue Pvectl::ResourceNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::NOT_FOUND
        rescue Timeout::Error => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        rescue Errno::ECONNREFUSED => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        rescue SocketError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONNECTION_ERROR
        end

        private

        # Outputs error for missing resource type argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_type_error
          $stderr.puts "Error: resource type is required"
          $stderr.puts "Usage: pvectl describe RESOURCE_TYPE NAME"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for missing resource name argument.
        #
        # @return [Integer] USAGE_ERROR exit code
        def missing_resource_name_error
          $stderr.puts "Error: resource name is required"
          $stderr.puts "Usage: pvectl describe #{@resource_type} NAME"
          ExitCodes::USAGE_ERROR
        end

        # Outputs error for unknown resource type.
        #
        # @return [Integer] USAGE_ERROR exit code
        def unknown_resource_error
          $stderr.puts "Unknown resource type: #{@resource_type}"
          ExitCodes::USAGE_ERROR
        end

        # Runs the describe operation with the given handler.
        #
        # @param handler [ResourceHandler] the resource handler
        # @return [void]
        def run_describe(handler)
          service = Services::Get::ResourceService.new(
            handler: handler,
            format: @global_options[:output] || "table",
            color_enabled: determine_color_enabled
          )
          output = service.describe(name: @resource_name, node: @options[:node], args: @extra_args, vmid: @options[:vmid])
          puts output
        end

        # Determines if color output should be enabled.
        #
        # @return [Boolean] true if color should be enabled
        def determine_color_enabled
          explicit = @global_options[:color]
          return explicit unless explicit.nil?

          $stdout.tty?
        end
      end
    end
  end
end
