# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared flag definitions for command registration.
    #
    # Provides reusable flag groups that multiple commands share.
    # Called during command registration to DRY up flag definitions.
    #
    # @example Usage in a command's register method
    #   def self.register(cli)
    #     cli.command :start do |c|
    #       SharedFlags.lifecycle(c)
    #       c.action { |g, o, a| ... }
    #     end
    #   end
    #
    module SharedFlags
      # Defines the 8 flags shared by all lifecycle commands.
      #
      # @param command [GLI::Command] the command to add flags to
      # @return [void]
      def self.lifecycle(command)
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

      # Defines config flags shared between VM and container operations.
      #
      # @param command [GLI::Command] the command to add flags to
      # @return [void]
      def self.common_config(command)
        command.desc "Number of CPU cores"
        command.flag [:cores], type: Integer, arg_name: "N"

        command.desc "Memory in MB"
        command.flag [:memory], type: Integer, arg_name: "MB"

        command.desc "Network config (repeatable): VM: bridge=X[,model=Y,tag=Z], CT: bridge=X[,name=Y,ip=Z]"
        command.flag [:net], arg_name: "CONFIG", multiple: true

        command.desc "Tags (comma-separated)"
        command.flag [:tags], arg_name: "TAGS"

        command.desc "Target node"
        command.flag [:node], arg_name: "NODE"

        command.desc "Start resource after operation"
        command.switch [:start], negatable: true, default_value: nil
      end

      # Defines VM-specific config flags.
      #
      # @param command [GLI::Command] the command to add flags to
      # @return [void]
      def self.vm_config(command)
        command.desc "Number of CPU sockets"
        command.flag [:sockets], type: Integer, arg_name: "N"

        command.desc "CPU type"
        command.flag [:"cpu-type"], arg_name: "TYPE"

        command.desc "Enable NUMA"
        command.switch [:numa], negatable: true, default_value: nil

        command.desc "Balloon memory in MB (0 to disable)"
        command.flag [:balloon], type: Integer, arg_name: "MB"

        command.desc "Disk config (repeatable)"
        command.flag [:disk], arg_name: "CONFIG", multiple: true

        command.desc "SCSI controller type"
        command.flag [:scsihw], arg_name: "TYPE"

        command.desc "CD-ROM ISO image"
        command.flag [:cdrom], arg_name: "ISO"

        command.desc "BIOS type"
        command.flag [:bios], arg_name: "TYPE"

        command.desc "Boot order"
        command.flag [:"boot-order"], arg_name: "ORDER"

        command.desc "Machine type"
        command.flag [:machine], arg_name: "TYPE"

        command.desc "EFI disk config"
        command.flag [:efidisk], arg_name: "CONFIG"

        command.desc "Cloud-init config"
        command.flag [:"cloud-init"], arg_name: "CONFIG"

        command.desc "Enable QEMU guest agent"
        command.switch [:agent], negatable: true, default_value: nil

        command.desc "OS type"
        command.flag [:ostype], arg_name: "TYPE"
      end

      # Defines container-specific config flags.
      #
      # @param command [GLI::Command] the command to add flags to
      # @return [void]
      def self.container_config(command)
        command.desc "Root filesystem config"
        command.flag [:rootfs], arg_name: "CONFIG"

        command.desc "Mount point config (repeatable)"
        command.flag [:mp], arg_name: "CONFIG", multiple: true

        command.desc "Swap size in MB"
        command.flag [:swap], type: Integer, arg_name: "MB"

        command.desc "Create privileged container"
        command.switch [:privileged], negatable: true, default_value: nil

        command.desc "Container features"
        command.flag [:features], arg_name: "FEATURES"

        command.desc "Root password"
        command.flag [:password], arg_name: "PASSWORD"

        command.desc "SSH public keys file"
        command.flag [:"ssh-public-keys"], arg_name: "FILE"

        command.desc "Start at boot"
        command.switch [:onboot], negatable: true, default_value: nil

        command.desc "Startup/shutdown order"
        command.flag [:startup], arg_name: "SPEC"
      end
    end
  end
end
