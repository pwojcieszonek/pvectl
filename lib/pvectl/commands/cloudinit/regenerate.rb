# frozen_string_literal: true

module Pvectl
  module Commands
    module Cloudinit
      # Handler for the `pvectl cloudinit regenerate vm <id>` subcommand.
      #
      # Triggers Proxmox to rebuild the cloud-init ISO from the current
      # VM configuration. The operation is synchronous on the Proxmox side
      # and returns null on success.
      #
      # @example Usage
      #   pvectl cloudinit regenerate vm 100
      #   pvectl cloudinit regenerate vm 100 --node pve2
      #
      class Regenerate
        # Registers the regenerate subcommand under the cloudinit parent.
        #
        # @param parent [GLI::Command] parent cloudinit command
        # @return [void]
        def self.register_subcommand(parent)
          parent.desc "Regenerate the cloud-init ISO for a VM"
          parent.long_desc <<~HELP
            DESCRIPTION
              Rebuild the cloud-init configuration drive (ISO) for a VM from
              the current Proxmox configuration. This is required after
              editing cloud-init-related options (user, ipconfig, sshkeys, etc.)
              for the changes to take effect inside the guest on next boot.

            EXAMPLES
              Regenerate cloud-init for VM 100:
                $ pvectl cloudinit regenerate vm 100

              Skip VMID lookup by passing the node explicitly:
                $ pvectl cloudinit regenerate vm 100 --node pve2

            NOTES
              Cloud-init is a VM-only feature — LXC containers do not expose
              cloud-init endpoints.

              The VM does NOT need to be running. The regenerated ISO will
              be picked up at the next guest reboot.

            SEE ALSO
              pvectl help cloudinit pending   Show pending cloud-init changes
              pvectl help cloudinit dump      Inspect generated cloud-init YAML
          HELP
          parent.arg_name "RESOURCE_TYPE ID"
          parent.command :regenerate do |c|
            c.action do |global_options, options, args|
              exit_code = execute(args, options, global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Executes the regenerate subcommand.
        #
        # @param args [Array<String>] command arguments (RESOURCE_TYPE, ID)
        # @param options [Hash] command-local options (:node)
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(args, options, global_options)
          resource_type = args[0]
          vmid_arg = args[1]

          return Cloudinit.usage_error("Resource type required (vm)") unless resource_type
          return Cloudinit.usage_error("VMID is required") unless vmid_arg
          return Cloudinit.unknown_resource_type(resource_type) unless resource_type == "vm"

          Cloudinit.with_service(global_options) do |service|
            result = service.regenerate(vmid_arg.to_i, node: options[:node])
            $stdout.puts "Cloud-init ISO regenerated for VM #{result[:vmid]} on #{result[:node]}."
          end
        end
      end
    end
  end
end
