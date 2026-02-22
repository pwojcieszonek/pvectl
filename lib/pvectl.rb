# frozen_string_literal: true

require_relative "pvectl/version"
require_relative "pvectl/exit_codes"
require_relative "pvectl/config_serializer"
require_relative "pvectl/editor_session"

# Main module for the pvectl application - CLI tool for managing Proxmox clusters.
#
# Pvectl provides a kubectl-style command line interface for managing
# virtual machines, containers, nodes, storage, and backups in Proxmox VE.
#
# @example Usage in code
#   Pvectl::CLI.run(ARGV)
#
# @see Pvectl::CLI Main CLI class
# @see Pvectl::ExitCodes Application exit codes
#
module Pvectl
  # Base error class for all pvectl-specific exceptions.
  #
  # All custom errors in the application should inherit from this class,
  # which allows for easy catching of all pvectl errors.
  #
  # @example Creating a custom error
  #   class ConnectionError < Pvectl::Error; end
  #
  # @example Catching pvectl errors
  #   begin
  #     # pvectl operations
  #   rescue Pvectl::Error => e
  #     puts "pvectl error: #{e.message}"
  #   end
  #
  class Error < StandardError; end

  # Raised when a requested resource is not found.
  #
  # @example
  #   raise Pvectl::ResourceNotFoundError, "Node not found: pve1"
  #
  class ResourceNotFoundError < Error; end
end

require_relative "pvectl/argv_preprocessor"

# Configuration management
require_relative "pvectl/config/errors"
require_relative "pvectl/config/models/cluster"
require_relative "pvectl/config/models/user"
require_relative "pvectl/config/models/context"
require_relative "pvectl/config/models/resolved_config"
require_relative "pvectl/config/provider"
require_relative "pvectl/config/store"
require_relative "pvectl/config/wizard"
require_relative "pvectl/config/service"

# Formatters
require_relative "pvectl/formatters/base"
require_relative "pvectl/formatters/color_support"
require_relative "pvectl/formatters/table"
require_relative "pvectl/formatters/wide"
require_relative "pvectl/formatters/json"
require_relative "pvectl/formatters/yaml"
require_relative "pvectl/formatters/registry"
require_relative "pvectl/formatters/output_helper"

# Models
require_relative "pvectl/models/base"
require_relative "pvectl/models/network_interface"
require_relative "pvectl/models/physical_disk"
require_relative "pvectl/models/service"
require_relative "pvectl/models/vm"
require_relative "pvectl/models/node"
require_relative "pvectl/models/storage"
require_relative "pvectl/models/snapshot"
require_relative "pvectl/models/snapshot_description"
require_relative "pvectl/models/backup"
require_relative "pvectl/models/container"
require_relative "pvectl/models/task"
require_relative "pvectl/models/operation_result"
require_relative "pvectl/models/vm_operation_result"
require_relative "pvectl/models/container_operation_result"
require_relative "pvectl/models/node_operation_result"
require_relative "pvectl/models/volume_operation_result"
require_relative "pvectl/models/task_entry"
require_relative "pvectl/models/syslog_entry"
require_relative "pvectl/models/journal_entry"
require_relative "pvectl/models/task_log_line"
require_relative "pvectl/models/volume"

# Repositories
require_relative "pvectl/repositories/base"
require_relative "pvectl/repositories/vm"
require_relative "pvectl/repositories/node"
require_relative "pvectl/repositories/storage"
require_relative "pvectl/repositories/container"
require_relative "pvectl/repositories/task"
require_relative "pvectl/repositories/snapshot"
require_relative "pvectl/repositories/backup"
require_relative "pvectl/repositories/task_list"
require_relative "pvectl/repositories/syslog"
require_relative "pvectl/repositories/journal"
require_relative "pvectl/repositories/task_log"
require_relative "pvectl/repositories/disk"
require_relative "pvectl/repositories/volume"

# Presenters
require_relative "pvectl/presenters/base"
require_relative "pvectl/presenters/config/context"
require_relative "pvectl/presenters/vm"
require_relative "pvectl/presenters/node"
require_relative "pvectl/presenters/top_presenter"
require_relative "pvectl/presenters/top_node"
require_relative "pvectl/presenters/top_vm"
require_relative "pvectl/presenters/storage"
require_relative "pvectl/presenters/container"
require_relative "pvectl/presenters/top_container"
require_relative "pvectl/presenters/operation_result"
require_relative "pvectl/presenters/vm_operation_result"
require_relative "pvectl/presenters/container_operation_result"
require_relative "pvectl/presenters/node_operation_result"
require_relative "pvectl/presenters/volume_operation_result"
require_relative "pvectl/presenters/snapshot"
require_relative "pvectl/presenters/snapshot_operation_result"
require_relative "pvectl/presenters/backup"
require_relative "pvectl/presenters/template"
require_relative "pvectl/presenters/task_entry"
require_relative "pvectl/presenters/syslog_entry"
require_relative "pvectl/presenters/journal_entry"
require_relative "pvectl/presenters/task_log_line"
require_relative "pvectl/presenters/disk"
require_relative "pvectl/presenters/volume"

# Selectors
require_relative "pvectl/selectors/base"
require_relative "pvectl/selectors/vm"
require_relative "pvectl/selectors/container"
require_relative "pvectl/selectors/disk"
require_relative "pvectl/selectors/volume"

# Console
require_relative "pvectl/console/terminal_session"

# Connection
require_relative "pvectl/connection/retry_handler"
require_relative "pvectl/connection"

# Utils
require_relative "pvectl/utils/resource_resolver"

# Parsers
require_relative "pvectl/parsers/disk_config"
require_relative "pvectl/parsers/net_config"
require_relative "pvectl/parsers/cloud_init_config"
require_relative "pvectl/parsers/lxc_mount_config"
require_relative "pvectl/parsers/lxc_net_config"
require_relative "pvectl/parsers/smart_text"

# Commands
require_relative "pvectl/commands/config/use_context"
require_relative "pvectl/commands/config/get_contexts"
require_relative "pvectl/commands/config/set_context"
require_relative "pvectl/commands/config/set_cluster"
require_relative "pvectl/commands/config/set_credentials"
require_relative "pvectl/commands/config/view"
require_relative "pvectl/commands/config/command"
require_relative "pvectl/commands/ping"

# Services - Get
require_relative "pvectl/services/get/resource_service"

# Services - Lifecycle
require_relative "pvectl/services/vm_lifecycle"
require_relative "pvectl/services/container_lifecycle"

# Services - Snapshot
require_relative "pvectl/services/snapshot"

# Services - Backup
require_relative "pvectl/services/backup"

# Services - Resource Delete
require_relative "pvectl/services/resource_delete"

# Services - Clone VM
require_relative "pvectl/services/clone_vm"

# Services - Create VM
require_relative "pvectl/services/create_vm"

# Services - Create Container
require_relative "pvectl/services/create_container"

# Services - Edit VM
require_relative "pvectl/services/edit_vm"

# Services - Edit Container
require_relative "pvectl/services/edit_container"

# Services - Set VM
require_relative "pvectl/services/set_vm"

# Services - Set Container
require_relative "pvectl/services/set_container"

# Services - Set Node
require_relative "pvectl/services/set_node"

# Services - Resize Volume
require_relative "pvectl/services/resize_volume"

# Services - Set Volume
require_relative "pvectl/services/set_volume"

# Services - Clone Container
require_relative "pvectl/services/clone_container"

# Services - Resource Migration
require_relative "pvectl/services/resource_migration"

# Services - Console
require_relative "pvectl/services/console"

# Services - Task Listing
require_relative "pvectl/services/task_listing"

# Commands - Base
require_relative "pvectl/commands/resource_registry"
require_relative "pvectl/commands/shared_flags"
require_relative "pvectl/commands/shared_config_parsers"

# Commands - Get
require_relative "pvectl/commands/get/resource_handler"
require_relative "pvectl/commands/get/resource_registry"
require_relative "pvectl/commands/get/watch_loop"
require_relative "pvectl/commands/get/command"
require_relative "pvectl/commands/get/handlers/vms"
require_relative "pvectl/commands/get/handlers/nodes"
require_relative "pvectl/commands/get/handlers/storage"
require_relative "pvectl/commands/get/handlers/containers"
require_relative "pvectl/commands/get/handlers/snapshots"
require_relative "pvectl/commands/get/handlers/backups"
require_relative "pvectl/commands/get/handlers/tasks"
require_relative "pvectl/commands/get/handlers/templates"
require_relative "pvectl/commands/get/handlers/disks"
require_relative "pvectl/commands/get/handlers/volume"

# Commands - Describe
require_relative "pvectl/commands/describe/command"

# Commands - Top
require_relative "pvectl/commands/top/resource_registry"
require_relative "pvectl/commands/top/resource_handler"
require_relative "pvectl/commands/top/command"
require_relative "pvectl/commands/top/handlers/nodes"
require_relative "pvectl/commands/top/handlers/vms"
require_relative "pvectl/commands/top/handlers/containers"

# Commands - Logs
require_relative "pvectl/commands/logs/resource_registry"
require_relative "pvectl/commands/logs/resource_handler"
require_relative "pvectl/commands/logs/command"
require_relative "pvectl/commands/logs/handlers/task_logs"
require_relative "pvectl/commands/logs/handlers/syslog"
require_relative "pvectl/commands/logs/handlers/journal"
require_relative "pvectl/commands/logs/handlers/task_detail"

# Commands - Lifecycle
require_relative "pvectl/commands/resource_lifecycle_command"
require_relative "pvectl/commands/vm_lifecycle_command"
require_relative "pvectl/commands/container_lifecycle_command"
require_relative "pvectl/commands/irreversible_command"
require_relative "pvectl/commands/delete_command"
require_relative "pvectl/commands/delete_vm"
require_relative "pvectl/commands/delete_container"
require_relative "pvectl/commands/template_command"
require_relative "pvectl/commands/template_vm"
require_relative "pvectl/commands/template_container"
require_relative "pvectl/commands/start"
require_relative "pvectl/commands/stop"
require_relative "pvectl/commands/shutdown"
require_relative "pvectl/commands/restart"
require_relative "pvectl/commands/reset"
require_relative "pvectl/commands/suspend"
require_relative "pvectl/commands/resume"
require_relative "pvectl/commands/start_container"
require_relative "pvectl/commands/stop_container"
require_relative "pvectl/commands/shutdown_container"
require_relative "pvectl/commands/restart_container"

# Commands - Create
require_relative "pvectl/commands/create_snapshot"
require_relative "pvectl/commands/create_backup"
require_relative "pvectl/commands/create_resource_command"
require_relative "pvectl/commands/create_vm"
require_relative "pvectl/commands/create_container"

# Commands - Edit
require_relative "pvectl/commands/edit_resource_command"
require_relative "pvectl/commands/edit_vm"
require_relative "pvectl/commands/edit_container"

# Commands - Resize
require_relative "pvectl/commands/resize/resize_volume_command"
require_relative "pvectl/commands/resize/resize_volume_vm"
require_relative "pvectl/commands/resize/resize_volume_ct"
require_relative "pvectl/commands/resize/command"

# Commands - Delete
require_relative "pvectl/commands/delete_snapshot"
require_relative "pvectl/commands/delete_backup"

# Commands - Rollback
require_relative "pvectl/commands/rollback_snapshot"

# Commands - Restore
require_relative "pvectl/commands/restore_backup"

# Commands - Clone
require_relative "pvectl/commands/clone_vm"
require_relative "pvectl/commands/clone_container"

# Commands - Migrate
require_relative "pvectl/commands/migrate_command"
require_relative "pvectl/commands/migrate_vm"
require_relative "pvectl/commands/migrate_container"

# Commands - Console
require_relative "pvectl/commands/console_vm"
require_relative "pvectl/commands/console_ct"
require_relative "pvectl/commands/console"

# Wizards
require_relative "pvectl/wizards/create_vm"
require_relative "pvectl/wizards/create_container"

require_relative "pvectl/plugin_loader"

require_relative "pvectl/cli"
