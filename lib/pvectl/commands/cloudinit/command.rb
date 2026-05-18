# frozen_string_literal: true

module Pvectl
  module Commands
    # Namespace for the +pvectl cloudinit+ command group.
    #
    # Provides three subcommands that operate on cloud-init configuration
    # of QEMU VMs:
    #
    # - +regenerate vm <id>+ — rebuild the cloud-init ISO
    # - +pending vm <id>+    — list pending configuration changes
    # - +dump vm <id> <type>+ — print generated cloud-init YAML
    #
    # All subcommands share a common service-construction helper and a
    # unified error-mapping path that distinguishes usage errors from
    # not-found and connection errors.
    module Cloudinit
      # Registers the cloudinit command group with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Manage cloud-init configuration for VMs"
        cli.long_desc <<~HELP
          DESCRIPTION
            Manage cloud-init configuration for QEMU virtual machines.
            Cloud-init lets you configure users, SSH keys, network, and
            other guest-side settings without baking them into the
            template image.

            Cloud-init is a VM-only feature — LXC containers do not
            expose cloud-init endpoints.

          SUBCOMMANDS
            cloudinit regenerate vm ID         Rebuild the cloud-init ISO
            cloudinit pending vm ID            List pending changes
            cloudinit dump vm ID TYPE          Print generated YAML

          EXAMPLES
            Apply pending cloud-init changes:
              $ pvectl cloudinit regenerate vm 100

            Preview what would change on next regenerate:
              $ pvectl cloudinit pending vm 100

            Inspect the user-data that the guest will see:
              $ pvectl cloudinit dump vm 100 user

          NOTES
            +TYPE+ for +dump+ must be one of: +user+, +network+, +meta+.

          SEE ALSO
            pvectl help edit vm   Edit cloud-init keys (cipassword, sshkeys, etc.)
        HELP
        cli.command :cloudinit do |c|
          c.desc "Source node (skips VMID lookup)"
          c.flag [:node, :n], arg_name: "NODE"

          Regenerate.register_subcommand(c)
          Pending.register_subcommand(c)
          Dump.register_subcommand(c)
        end
      end

      # Builds a fresh +Services::Cloudinit+ from the active configuration
      # and yields it to the caller. Maps known exceptions to pvectl exit
      # codes — anything else bubbles up to +CLI.on_error+.
      #
      # @param global_options [Hash] global CLI options (includes :config)
      # @yieldparam service [Pvectl::Services::Cloudinit] cloudinit service
      # @return [Integer] exit code
      def self.with_service(global_options)
        config_service = Pvectl::Config::Service.new
        config_service.load(config: global_options[:config])
        config = config_service.current_config

        connection = Pvectl::Connection.new(config)
        service = Pvectl::Services::Cloudinit.new(
          vm_repository: Pvectl::Repositories::Vm.new(connection),
          resource_resolver: Pvectl::Utils::ResourceResolver.new(connection)
        )

        yield service
        Pvectl::ExitCodes::SUCCESS
      rescue Pvectl::ResourceNotFoundError => e
        $stderr.puts "Error: #{e.message}"
        Pvectl::ExitCodes::NOT_FOUND
      rescue ArgumentError => e
        $stderr.puts "Error: #{e.message}"
        Pvectl::ExitCodes::USAGE_ERROR
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        Pvectl::ExitCodes::GENERAL_ERROR
      end

      # Prints a usage error and returns the standard usage exit code.
      #
      # @param message [String] message printed to stderr
      # @return [Integer] usage error exit code
      def self.usage_error(message)
        $stderr.puts "Error: #{message}"
        Pvectl::ExitCodes::USAGE_ERROR
      end

      # Prints the standard "unknown resource type" error.
      #
      # @param resource_type [String] the unrecognised resource type
      # @return [Integer] usage error exit code
      def self.unknown_resource_type(resource_type)
        $stderr.puts "Error: Unknown or invalid resource type for cloudinit: #{resource_type}"
        $stderr.puts "Valid types: vm"
        Pvectl::ExitCodes::USAGE_ERROR
      end
    end
  end
end
