# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl feature vm` command.
    #
    # Queries whether a Proxmox feature (clone, snapshot, copy) is available
    # for a virtual machine. Availability depends on storage type, snapshot
    # state, and other server-side conditions.
    #
    # Also registers the top-level `feature` GLI command and dispatches
    # to FeatureVm or FeatureContainer based on the resource type.
    #
    # @example Check whether VM 100 can be cloned
    #   pvectl feature vm 100 clone
    #
    # @example Check snapshot feature against a specific snapshot
    #   pvectl feature vm 100 snapshot --snapname pre-upgrade
    #
    class FeatureVm
      include FeatureCommand

      # Registers the feature command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Query whether a feature (clone/snapshot/copy) is available"
        cli.long_desc <<~HELP
          Check whether a Proxmox feature is available for a VM or container.
          Availability depends on the storage type backing the disks, current
          snapshot state, and other server-side conditions.

          Exit code is 0 when the feature is available, 1 when unavailable,
          5 when the resource is not found, and 2 on invalid usage.

          EXAMPLES
            Check whether VM 100 can be cloned:
              $ pvectl feature vm 100 clone

            Check snapshot feature on a container with a specific snapshot:
              $ pvectl feature ct 200 snapshot --snapname pre-upgrade

            Check copy feature for a VM:
              $ pvectl feature vm 100 copy

            JSON output (machine-readable):
              $ pvectl feature vm 100 clone -o json

          NOTES
            Supported features: clone, snapshot, copy.

            The Proxmox API returns the list of cluster nodes that can host
            the resource after the requested feature is applied. For VMs the
            list is printed under the "nodes:" line; for containers the LXC
            endpoint does not return this list.

            --snapname is required for some checks (e.g. checking whether a
            specific snapshot can be removed or cloned from).

          SEE ALSO
            pvectl help clone           Clone a VM or container
            pvectl help create snapshot Create a snapshot
            pvectl help get snapshots   List snapshots
        HELP
        cli.arg_name "RESOURCE_TYPE ID FEATURE"
        cli.command :feature do |c|
          c.desc "Snapshot name (optional, required for some checks)"
          c.flag [:snapname], arg_name: "NAME"

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::FeatureVm.execute(args, options, global_options)
            when "container", "ct"
              Commands::FeatureContainer.execute(args, options, global_options)
            else
              $stderr.puts "Error: Unknown resource type: #{resource_type}"
              $stderr.puts "Valid types: vm, container, ct"
              ExitCodes::USAGE_ERROR
            end

            exit exit_code if exit_code != 0
          end
        end
      end

      RESOURCE_TYPE = :vm
      SUPPORTED_RESOURCES = %w[vm].freeze
    end
  end
end
