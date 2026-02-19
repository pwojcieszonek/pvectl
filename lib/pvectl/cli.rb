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

    # @!endgroup

    # --- Load all commands (built-in + plugins) ---
    Pvectl::PluginLoader.load_all(self)
  end
end
