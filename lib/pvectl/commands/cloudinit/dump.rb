# frozen_string_literal: true

module Pvectl
  module Commands
    module Cloudinit
      # Handler for the `pvectl cloudinit dump vm <id> <type>` subcommand.
      #
      # Prints the generated cloud-init configuration to stdout as raw
      # YAML/text. The +type+ argument selects which document is dumped:
      # +user+ (user-data), +network+ (network-config), or +meta+
      # (meta-data).
      #
      # @example Usage
      #   pvectl cloudinit dump vm 100 user
      #   pvectl cloudinit dump vm 100 network
      #
      class Dump
        # Registers the dump subcommand under the cloudinit parent.
        #
        # @param parent [GLI::Command] parent cloudinit command
        # @return [void]
        def self.register_subcommand(parent)
          parent.desc "Dump generated cloud-init configuration for a VM"
          parent.long_desc <<~HELP
            DESCRIPTION
              Print the auto-generated cloud-init configuration that would
              be served to the guest. The +TYPE+ argument selects which
              cloud-init document to display:

                user     User-data (#cloud-config YAML)
                network  Network-config (cloud-init network spec)
                meta     Meta-data (instance-id, hostname)

            EXAMPLES
              Dump user-data:
                $ pvectl cloudinit dump vm 100 user

              Dump network-config:
                $ pvectl cloudinit dump vm 100 network

              Pipe to a file:
                $ pvectl cloudinit dump vm 100 user > user-data.yml

            NOTES
              The output is the raw payload returned by Proxmox — no
              additional formatting is applied. This means +-o json+ is
              ignored for this subcommand.

            SEE ALSO
              pvectl help cloudinit regenerate   Rebuild the ISO
              pvectl help cloudinit pending      Show pending changes
          HELP
          parent.arg_name "RESOURCE_TYPE ID TYPE"
          parent.command :dump do |c|
            c.action do |global_options, options, args|
              exit_code = execute(args, options, global_options)
              exit exit_code if exit_code != 0
            end
          end
        end

        # Valid cloud-init dump types.
        VALID_TYPES = %w[user network meta].freeze

        # Executes the dump subcommand.
        #
        # @param args [Array<String>] command arguments (RESOURCE_TYPE, ID, TYPE)
        # @param options [Hash] command-local options
        # @param global_options [Hash] global CLI options
        # @return [Integer] exit code
        def self.execute(args, options, global_options)
          resource_type = args[0]
          vmid_arg = args[1]
          type = args[2]

          return Cloudinit.usage_error("Resource type required (vm)") unless resource_type
          return Cloudinit.usage_error("VMID is required") unless vmid_arg
          return Cloudinit.usage_error("Config TYPE is required (user, network, meta)") unless type
          return Cloudinit.unknown_resource_type(resource_type) unless resource_type == "vm"
          unless VALID_TYPES.include?(type)
            return Cloudinit.usage_error(
              "Invalid config type: #{type} (valid: #{VALID_TYPES.join(', ')})"
            )
          end

          Cloudinit.with_service(global_options) do |service|
            yaml = service.dump(vmid_arg.to_i, type, node: options[:node])
            $stdout.puts yaml
          end
        end
      end
    end
  end
end
