# frozen_string_literal: true

require "gli"

module Pvectl
  # Main CLI class using the GLI framework.
  #
  # The CLI class is the entry point for the pvectl command line interface.
  # It is responsible for:
  # - Parsing command line arguments
  # - Routing to appropriate commands (get, describe, create, delete, etc.)
  # - Handling global flags (--output, --verbose, --config)
  # - Error handling and system signal handling
  #
  # Uses the GLI (Git-Like Interface) framework to create commands
  # in kubectl/git style.
  #
  # @example Running CLI
  #   Pvectl::CLI.run(ARGV)
  #
  # @example Typical command line usage
  #   pvectl get nodes                    # List nodes
  #   pvectl get vms -o json              # List VMs in JSON format
  #   pvectl describe vm 100 --verbose    # VM details with debugging
  #
  # @see https://github.com/davetron5000/gli GLI documentation
  # @see Pvectl::ExitCodes Exit codes used by CLI
  #
  class CLI
    extend GLI::App

    # Program configuration - description and version shown in --help and --version
    program_desc "CLI tool for managing Proxmox clusters with kubectl-like syntax"
    version Pvectl::VERSION

    # Enable normal flag processing in subcommands
    # Note: We do NOT use 'arguments :strict' to allow flexible flag/argument ordering
    subcommand_option_handling :normal

    # @!group Global flags

    desc "Output format (table, json, yaml, wide)"
    arg_name "FORMAT"
    default_value "table"
    flag [:o, :output], must_match: %w[table json yaml wide]

    desc "Enable verbose output for debugging"
    switch [:v, :verbose], negatable: false

    desc "Path to configuration file"
    arg_name "FILE"
    flag [:c, :config]

    desc "Force colored output (even when not TTY)"
    switch [:color], negatable: true, default_value: nil

    # @!endgroup

    # Error handling - maps exceptions to appropriate exit codes.
    #
    # @param exception [Exception] caught exception
    # @return [void]
    on_error do |exception|
      case exception
      when SystemExit
        # Re-raise SystemExit to preserve the exit code
        raise
      when GLI::BadCommandLine, GLI::UnknownCommand
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::USAGE_ERROR
      when Pvectl::ArgvPreprocessor::DuplicateFlagError
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::USAGE_ERROR
      when Pvectl::Config::ContextNotFoundError,
           Pvectl::Config::ClusterNotFoundError,
           Pvectl::Config::UserNotFoundError,
           Pvectl::Config::ConfigNotFoundError,
           Pvectl::Config::InvalidConfigError
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::CONFIG_ERROR
      else
        $stderr.puts "Error: #{exception.message}"
        $stderr.puts exception.backtrace.join("\n") if ENV["GLI_DEBUG"] == "true"
        exit ExitCodes::GENERAL_ERROR
      end
    end

    # SIGINT (Ctrl+C) handling - clean exit with code 130
    trap("INT") do
      $stderr.puts "\nInterrupted"
      exit ExitCodes::INTERRUPTED
    end

    # @!group Commands

    # Private helper to define common flags for lifecycle commands (start, stop, shutdown, etc)
    #
    # Extracts flag definitions used by all 7 lifecycle commands to eliminate duplication.
    # This follows the DRY principle - the identical 7 flags are defined once here.
    #
    # @param command [GLI::Command] the command object to add flags to
    # @return [void]
    #
    # @private
    def self.define_lifecycle_flags(command)
      command.desc "Timeout in seconds for sync operations"
      command.flag [:timeout], type: Integer, arg_name: "SECONDS"

      command.desc "Force async mode (return task ID immediately)"
      command.switch [:async], negatable: false

      command.desc "Force sync mode (wait for completion)"
      command.switch [:wait], negatable: false

      command.desc "Select all VMs"
      command.switch [:all, :A], negatable: false

      command.desc "Filter by node name"
      command.flag [:node, :n], arg_name: "NODE"

      command.desc "Skip confirmation prompt"
      command.switch [:yes, :y], negatable: false

      command.desc "Stop on first error (default: continue and report all)"
      command.switch [:"fail-fast"], negatable: false

      command.desc "Filter VMs by selector (e.g., status=running,tags=prod)"
      command.flag [:l, :selector], arg_name: "SELECTOR", multiple: true
    end

    # Get command - list resources in cluster
    desc "List resources in cluster"
    command :get do |c|
      c.desc "Filter by node name"
      c.flag [:node], arg_name: "NODE"

      c.desc "Filter by storage (for backups)"
      c.flag [:storage], arg_name: "STORAGE"

      c.desc "Watch for changes with auto-refresh"
      c.switch [:watch, :w], negatable: false

      c.desc "Watch refresh interval in seconds (default: 2, minimum: 1)"
      c.default_value 2
      c.flag [:"watch-interval"], arg_name: "SECONDS", type: Integer

      c.action do |global_options, options, args|
        resource_type = args[0]
        resource_args = args[1..] || []
        exit_code = Commands::Get::Command.execute(
          resource_type,
          resource_args,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Top command - display resource usage metrics
    desc "Display resource usage metrics (CPU, memory, disk)"
    arg_name "RESOURCE_TYPE"
    command :top do |c|
      c.desc "Sort by field (cpu, memory, disk, netin, netout, name, node)"
      c.flag [:"sort-by"], arg_name: "FIELD"

      c.desc "Show all (including stopped)"
      c.switch [:all], default_value: false

      c.action do |global_options, options, args|
        resource_type = args[0]
        exit_code = Commands::Top::Command.execute(
          resource_type,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Logs command - view logs for resources
    desc "Show logs for resources (task history, syslog, journal)"
    arg_name "RESOURCE_TYPE ID"
    command :logs do |c|
      c.desc "Maximum number of entries to show"
      c.default_value 50
      c.flag [:limit], type: Integer, arg_name: "N"

      c.desc "Show entries since timestamp (YYYY-MM-DD or epoch)"
      c.flag [:since], arg_name: "TIMESTAMP"

      c.desc "Show entries until timestamp (YYYY-MM-DD or epoch)"
      c.flag [:until], arg_name: "TIMESTAMP"

      c.desc "Filter by task type (e.g., qmstart, qmstop, vzdump)"
      c.flag [:type], arg_name: "TYPE"

      c.desc "Filter by status (running, ok, error)"
      c.flag [:status], arg_name: "STATUS"

      c.desc "Filter by service name (syslog only)"
      c.flag [:service], arg_name: "SERVICE"

      c.desc "Use systemd journal instead of syslog (node only)"
      c.switch [:journal], negatable: false

      c.desc "Search across all cluster nodes (VM/CT only)"
      c.switch [:"all-nodes"], negatable: false

      c.action do |global_options, options, args|
        resource_type = args[0]
        resource_id = args[1]
        exit_code = Commands::Logs::Command.execute(
          resource_type,
          resource_id,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Describe command - show detailed information about a resource
    desc "Show detailed information about a resource"
    arg_name "RESOURCE_TYPE NAME"
    command :describe do |c|
      c.desc "Filter by node name (required for local storage)"
      c.flag [:node], arg_name: "NODE"

      c.action do |global_options, options, args|
        resource_type = args[0]
        resource_name = args[1]
        exit_code = Commands::Describe::Command.execute(
          resource_type,
          resource_name,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Ping command - check connectivity to Proxmox cluster
    desc "Check connectivity to Proxmox cluster"
    command :ping do |c|
      c.action do |global_options, _options, _args|
        exit_code = Commands::Ping.execute(global_options)
        exit exit_code if exit_code != 0
      end
    end

    # Start command - start VMs or containers
    desc "Start virtual machines or containers"
    arg_name "RESOURCE_TYPE [ID...]"
    command :start do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = case resource_type
        when "container", "ct"
          Commands::StartContainer.execute(resource_type, resource_ids, options, global_options)
        else
          Commands::Start.execute(resource_type, resource_ids, options, global_options)
        end
        exit exit_code if exit_code != 0
      end
    end

    # Stop command - stop VMs or containers (hard stop)
    desc "Stop virtual machines or containers (hard stop)"
    arg_name "RESOURCE_TYPE [ID...]"
    command :stop do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = case resource_type
        when "container", "ct"
          Commands::StopContainer.execute(resource_type, resource_ids, options, global_options)
        else
          Commands::Stop.execute(resource_type, resource_ids, options, global_options)
        end
        exit exit_code if exit_code != 0
      end
    end

    # Shutdown command - shutdown VMs or containers gracefully
    desc "Shutdown virtual machines or containers gracefully"
    arg_name "RESOURCE_TYPE [ID...]"
    command :shutdown do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = case resource_type
        when "container", "ct"
          Commands::ShutdownContainer.execute(resource_type, resource_ids, options, global_options)
        else
          Commands::Shutdown.execute(resource_type, resource_ids, options, global_options)
        end
        exit exit_code if exit_code != 0
      end
    end

    # Restart command - restart VMs or containers (reboot)
    desc "Restart virtual machines or containers (reboot)"
    arg_name "RESOURCE_TYPE [ID...]"
    command :restart do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = case resource_type
        when "container", "ct"
          Commands::RestartContainer.execute(resource_type, resource_ids, options, global_options)
        else
          Commands::Restart.execute(resource_type, resource_ids, options, global_options)
        end
        exit exit_code if exit_code != 0
      end
    end

    # Reset command - reset VMs (hard reset)
    desc "Reset virtual machines (hard reset)"
    arg_name "RESOURCE_TYPE [VMID...]"
    command :reset do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = Commands::Reset.execute(
          resource_type,
          resource_ids,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Suspend command - suspend VMs (hibernate)
    desc "Suspend virtual machines (hibernate)"
    arg_name "RESOURCE_TYPE [VMID...]"
    command :suspend do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = Commands::Suspend.execute(
          resource_type,
          resource_ids,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Resume command - resume suspended VMs
    desc "Resume suspended virtual machines"
    arg_name "RESOURCE_TYPE [VMID...]"
    command :resume do |c|
      define_lifecycle_flags(c)

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args
        exit_code = Commands::Resume.execute(
          resource_type,
          resource_ids,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Create command - create resources
    desc "Create a resource"
    arg_name "RESOURCE_TYPE [VMID...]"
    command :create do |c|
      # Snapshot-specific flags
      c.desc "Snapshot name (required for snapshots)"
      c.flag [:name], arg_name: "NAME"

      c.desc "Description/notes"
      c.flag [:description, :notes], arg_name: "TEXT"

      c.desc "Save VM memory state (QEMU only, snapshots)"
      c.switch [:vmstate], negatable: false

      # Backup-specific flags
      c.desc "Target storage for backup"
      c.flag [:storage], arg_name: "STORAGE"

      c.desc "Backup mode (snapshot, suspend, stop)"
      c.default_value "snapshot"
      c.flag [:mode], arg_name: "MODE", must_match: %w[snapshot suspend stop]

      c.desc "Compression (zstd, gzip, lzo, 0 for none)"
      c.default_value "zstd"
      c.flag [:compress], arg_name: "TYPE"

      c.desc "Protect backup from deletion"
      c.switch [:protected], negatable: false

      # Common flags
      c.desc "Skip confirmation prompt"
      c.switch [:yes, :y], negatable: false

      c.desc "Timeout in seconds for sync operations"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.desc "Force async mode (return task ID immediately)"
      c.switch [:async], negatable: false

      c.desc "Stop on first error (default: continue and report all)"
      c.switch [:"fail-fast"], negatable: false

      # Shared VM/container flags
      c.desc "Number of CPU cores"
      c.flag [:cores], type: Integer, arg_name: "N"

      c.desc "Number of CPU sockets (VM)"
      c.flag [:sockets], type: Integer, arg_name: "N"

      c.desc "CPU model type (VM)"
      c.flag [:"cpu-type"], arg_name: "TYPE"

      c.desc "Enable NUMA (VM)"
      c.switch [:numa], negatable: false

      c.desc "Memory in MB"
      c.flag [:memory], type: Integer, arg_name: "MB"

      c.desc "Balloon minimum memory in MB (VM)"
      c.flag [:balloon], type: Integer, arg_name: "MB"

      c.desc "Disk config (VM, repeatable): storage=X,size=Y[,format=Z,...]"
      c.flag [:disk], arg_name: "CONFIG", multiple: true

      c.desc "SCSI controller type (VM)"
      c.flag [:scsihw], arg_name: "TYPE"

      c.desc "CD-ROM/ISO path (VM): storage:iso/name.iso"
      c.flag [:cdrom], arg_name: "ISO"

      c.desc "Network config (repeatable): VM: bridge=X[,model=Y,tag=Z], CT: bridge=X[,name=Y,ip=Z]"
      c.flag [:net], arg_name: "CONFIG", multiple: true

      c.desc "BIOS firmware (VM): seabios or ovmf"
      c.flag [:bios], arg_name: "TYPE"

      c.desc "Boot order (VM)"
      c.flag [:"boot-order"], arg_name: "ORDER"

      c.desc "Machine type (VM): q35, pc"
      c.flag [:machine], arg_name: "TYPE"

      c.desc "EFI disk config (VM): storage=X[,size=Y]"
      c.flag [:efidisk], arg_name: "CONFIG"

      c.desc "Cloud-init config (VM): user=X,password=Y,ip=dhcp,..."
      c.flag [:"cloud-init"], arg_name: "CONFIG"

      c.desc "Enable QEMU guest agent (VM)"
      c.switch [:agent], negatable: false

      c.desc "OS type (VM): l26, win11, other, etc."
      c.flag [:ostype], arg_name: "TYPE"

      c.desc "Tags (comma-separated)"
      c.flag [:tags], arg_name: "TAGS"

      c.desc "Resource pool"
      c.flag [:pool], arg_name: "POOL"

      c.desc "Start resource after creation"
      c.switch [:start], negatable: false

      c.desc "Force interactive wizard mode"
      c.switch [:interactive], negatable: true

      c.desc "Show what would happen without creating"
      c.switch [:"dry-run"], negatable: false

      c.desc "Target node"
      c.flag [:node], arg_name: "NODE"

      # Container-specific flags
      c.desc "Container hostname (container)"
      c.flag [:hostname], arg_name: "NAME"

      c.desc "OS template path (container): storage:vztmpl/name.tar.zst"
      c.flag [:ostemplate], arg_name: "TEMPLATE"

      c.desc "Root filesystem (container): storage=X,size=Y"
      c.flag [:rootfs], arg_name: "CONFIG"

      c.desc "Mountpoint (container, repeatable): mp=/path,storage=X,size=Y"
      c.flag [:mp], arg_name: "CONFIG", multiple: true

      c.desc "Swap in MB (container)"
      c.flag [:swap], type: Integer, arg_name: "MB"

      c.desc "Create privileged container (container, default: unprivileged)"
      c.switch [:privileged], negatable: false

      c.desc "LXC features (container): nesting=1,keyctl=1"
      c.flag [:features], arg_name: "FEATURES"

      c.desc "Root password (container)"
      c.flag [:password], arg_name: "PASSWORD"

      c.desc "SSH public keys file (container)"
      c.flag [:"ssh-public-keys"], arg_name: "FILE"

      c.desc "Start on boot (container)"
      c.switch [:onboot], negatable: false

      c.desc "Startup order spec (container)"
      c.flag [:startup], arg_name: "SPEC"

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args

        exit_code = case resource_type
        when "vm"
          Commands::CreateVm.execute(resource_ids, options, global_options)
        when "container", "ct"
          Commands::CreateContainer.execute(resource_ids, options, global_options)
        when "snapshot"
          Commands::CreateSnapshot.execute(resource_type, resource_ids, options, global_options)
        when "backup"
          # Map :description to :notes for backup if notes not set
          options[:notes] ||= options[:description]
          Commands::CreateBackup.execute(resource_type, resource_ids, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: vm, container, snapshot, backup"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Edit command - edit resource configuration in $EDITOR
    desc "Edit a resource configuration"
    long_desc "Opens the current configuration of a VM or container in your $EDITOR as YAML. " \
              "After editing, validates changes and applies them to the Proxmox API."
    arg_name "RESOURCE_TYPE RESOURCE_ID"
    command :edit do |c|
      c.desc "Override editor command (default: $EDITOR or vi)"
      c.flag [:editor], arg_name: "CMD"

      c.desc "Show diff without applying changes"
      c.switch [:"dry-run"], negatable: false

      c.action do |global_options, options, args|
        resource_type = args.shift
        resource_ids = args

        exit_code = case resource_type
        when "vm"
          Commands::EditVm.execute(resource_ids, options, global_options)
        when "container", "ct"
          Commands::EditContainer.execute(resource_ids, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: vm, container"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Clone command - clone resources
    desc "Clone a resource"
    arg_name "RESOURCE_TYPE VMID"
    command :clone do |c|
      c.desc "Name/hostname for the new resource"
      c.flag [:name, :n], arg_name: "NAME"

      c.desc "ID for the new resource (auto-selected if not specified)"
      c.flag [:vmid], type: Integer, arg_name: "ID"

      c.desc "Target node for the clone"
      c.flag [:target, :t], arg_name: "NODE"

      c.desc "Target storage for the clone"
      c.flag [:storage, :s], arg_name: "STORAGE"

      c.desc "Create a linked clone (requires source to be a template)"
      c.switch [:linked], negatable: false

      c.desc "Resource pool for the new resource"
      c.flag [:pool, :p], arg_name: "POOL"

      c.desc "Description for the new resource"
      c.flag [:description, :d], arg_name: "DESCRIPTION"

      c.desc "Timeout in seconds for sync operations (default: 300)"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.desc "Async mode (return task ID immediately)"
      c.switch [:async], negatable: false

      c.action do |global_options, options, args|
        resource_type = args.shift

        exit_code = case resource_type
        when "vm"
          Commands::CloneVm.execute(args, options, global_options)
        when "container", "ct"
          Commands::CloneContainer.execute(args, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: vm, container, ct"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Delete command - delete resources
    desc "Delete a resource"
    arg_name "RESOURCE_TYPE [ID...] [NAME]"
    command :delete do |c|
      c.desc "Skip confirmation prompt (REQUIRED for destructive operations)"
      c.switch [:yes, :y], negatable: false

      c.desc "Force stop running VM/container before deletion"
      c.switch [:force, :f], negatable: false

      c.desc "Keep disks (do not destroy)"
      c.switch [:"keep-disks"], negatable: false

      c.desc "Remove from HA, replication, and backups"
      c.switch [:purge], negatable: false

      c.desc "Select all resources of this type"
      c.switch [:all, :A], negatable: false

      c.desc "Filter by node name"
      c.flag [:node, :n], arg_name: "NODE"

      c.desc "Filter by selector (e.g., status=running,tags=prod)"
      c.flag [:l, :selector], arg_name: "SELECTOR", multiple: true

      c.desc "Timeout in seconds for sync operations"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.desc "Force async mode (return task ID immediately)"
      c.switch [:async], negatable: false

      c.desc "Stop on first error (default: continue and report all)"
      c.switch [:"fail-fast"], negatable: false

      c.action do |global_options, options, args|
        resource_type = args.shift

        exit_code = case resource_type
        when "vm"
          Commands::DeleteVm.execute(resource_type, args, options, global_options)
        when "container", "ct"
          Commands::DeleteContainer.execute(resource_type, args, options, global_options)
        when "snapshot"
          Commands::DeleteSnapshot.execute(resource_type, args, options, global_options)
        when "backup"
          Commands::DeleteBackup.execute(resource_type, args, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: vm, container, ct, snapshot, backup"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Migrate command - migrate resources between nodes
    desc "Migrate a resource to another node"
    arg_name "RESOURCE_TYPE [ID...]"
    command :migrate do |c|
      c.desc "Target node (required)"
      c.flag [:target, :t], arg_name: "NODE"

      c.desc "Online/live migration"
      c.switch [:online], negatable: false

      c.desc "Restart migration (container only)"
      c.switch [:restart], negatable: false

      c.desc "Target storage mapping"
      c.flag [:"target-storage"], arg_name: "STORAGE"

      c.desc "Select all resources of this type"
      c.switch [:all, :A], negatable: false

      c.desc "Filter by source node"
      c.flag [:node, :n], arg_name: "NODE"

      c.desc "Filter by selector (e.g., status=running,tags=prod)"
      c.flag [:l, :selector], arg_name: "SELECTOR", multiple: true

      c.desc "Skip confirmation prompt"
      c.switch [:yes, :y], negatable: false

      c.desc "Stop on first error"
      c.switch [:"fail-fast"], negatable: false

      c.desc "Wait for migration to complete (sync mode)"
      c.switch [:wait], negatable: false

      c.desc "Timeout in seconds for sync operations (default: 600)"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.action do |global_options, options, args|
        resource_type = args.shift

        exit_code = case resource_type
        when "vm"
          Commands::MigrateVm.execute(args, options, global_options)
        when "container", "ct"
          Commands::MigrateContainer.execute(args, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: vm, container, ct"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Rollback command - rollback to snapshot
    desc "Rollback to a snapshot"
    arg_name "RESOURCE_TYPE VMID SNAPSHOT_NAME"
    command :rollback do |c|
      c.desc "Skip confirmation prompt (REQUIRED for destructive operations)"
      c.switch [:yes, :y], negatable: false

      c.desc "Start VM/container after rollback (LXC only)"
      c.switch [:start], negatable: false

      c.desc "Timeout in seconds for sync operations"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.desc "Force async mode (return task ID immediately)"
      c.switch [:async], negatable: false

      c.action do |global_options, options, args|
        resource_type = args.shift
        exit_code = Commands::RollbackSnapshot.execute(
          resource_type,
          args,
          options,
          global_options
        )
        exit exit_code if exit_code != 0
      end
    end

    # Restore command - restore from backup
    desc "Restore a resource from backup"
    arg_name "RESOURCE_TYPE VOLID"
    command :restore do |c|
      c.desc "Target VMID (required)"
      c.flag [:vmid], arg_name: "VMID", type: Integer

      c.desc "Target storage"
      c.flag [:storage], arg_name: "STORAGE"

      c.desc "Overwrite existing VM/container"
      c.switch [:force], negatable: false

      c.desc "Start after restore"
      c.switch [:start], negatable: false

      c.desc "Regenerate unique properties (MAC, UUID)"
      c.switch [:unique], negatable: false

      c.desc "Skip confirmation prompt (REQUIRED)"
      c.switch [:yes, :y], negatable: false

      c.desc "Timeout in seconds"
      c.flag [:timeout], type: Integer, arg_name: "SECONDS"

      c.desc "Force async mode"
      c.switch [:async], negatable: false

      c.action do |global_options, options, args|
        resource_type = args.shift
        volid = args.first

        exit_code = case resource_type
        when "backup"
          Commands::RestoreBackup.execute(resource_type, volid, options, global_options)
        else
          $stderr.puts "Error: Unknown resource type: #{resource_type}"
          $stderr.puts "Valid types: backup"
          ExitCodes::USAGE_ERROR
        end

        exit exit_code if exit_code != 0
      end
    end

    # Config command - manage configuration contexts
    desc "Manage pvectl configuration"
    command :config do |c|
      # use-context subcommand
      c.desc "Switch to a different context"
      c.command :"use-context" do |use_ctx|
        use_ctx.arg_name "CONTEXT_NAME"
        use_ctx.action do |global_options, _options, args|
          if args.empty?
            $stderr.puts "Error: context name is required"
            exit ExitCodes::USAGE_ERROR
          end
          exit_code = Commands::Config::UseContext.execute(args[0], global_options)
          exit exit_code if exit_code != 0
        end
      end

      # get-contexts subcommand
      c.desc "List all available contexts"
      c.command :"get-contexts" do |get_ctx|
        get_ctx.action do |global_options, _options, _args|
          exit_code = Commands::Config::GetContexts.execute(global_options)
          exit exit_code if exit_code != 0
        end
      end

      # set-context subcommand
      c.desc "Create or modify a context"
      c.command :"set-context" do |set_ctx|
        set_ctx.arg_name "CONTEXT_NAME"

        set_ctx.desc "Cluster name"
        set_ctx.flag [:cluster]

        set_ctx.desc "User name"
        set_ctx.flag [:user]

        set_ctx.desc "Default node"
        set_ctx.flag [:"default-node"]

        set_ctx.action do |global_options, options, args|
          if args.empty?
            $stderr.puts "Error: context name is required"
            exit ExitCodes::USAGE_ERROR
          end
          exit_code = Commands::Config::SetContext.execute(args[0], options, global_options)
          exit exit_code if exit_code != 0
        end
      end

      # set-cluster subcommand
      c.desc "Create or modify a cluster"
      c.command :"set-cluster" do |set_cluster|
        set_cluster.arg_name "CLUSTER_NAME"

        set_cluster.desc "Proxmox server URL (e.g., https://pve.example.com:8006)"
        set_cluster.flag [:server]

        set_cluster.desc "Path to CA certificate file"
        set_cluster.flag [:"certificate-authority"]

        set_cluster.desc "Skip TLS certificate verification"
        set_cluster.switch [:"insecure-skip-tls-verify"], negatable: false

        set_cluster.action do |global_options, options, args|
          if args.empty?
            $stderr.puts "Error: cluster name is required"
            exit ExitCodes::USAGE_ERROR
          end
          exit_code = Commands::Config::SetCluster.execute(args[0], options, global_options)
          exit exit_code if exit_code != 0
        end
      end

      # set-credentials subcommand
      c.desc "Create or modify user credentials"
      c.command :"set-credentials" do |set_creds|
        set_creds.arg_name "USER_NAME"

        set_creds.desc "API token ID (e.g., root@pam!tokenname)"
        set_creds.flag [:"token-id"]

        set_creds.desc "API token secret"
        set_creds.flag [:"token-secret"]

        set_creds.desc "Username for password authentication"
        set_creds.flag [:username]

        set_creds.desc "Password for password authentication"
        set_creds.flag [:password]

        set_creds.action do |global_options, options, args|
          if args.empty?
            $stderr.puts "Error: user name is required"
            exit ExitCodes::USAGE_ERROR
          end
          exit_code = Commands::Config::SetCredentials.execute(args[0], options, global_options)
          exit exit_code if exit_code != 0
        end
      end

      # view subcommand
      c.desc "Display current configuration with masked secrets"
      c.command :view do |view|
        view.action do |global_options, _options, _args|
          exit_code = Commands::Config::View.execute(global_options)
          exit exit_code if exit_code != 0
        end
      end
    end

    # @!endgroup
  end
end
