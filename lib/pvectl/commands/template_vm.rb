# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl template vm` command.
    #
    # Converts one or more VMs to templates (irreversible).
    # Always requires confirmation (--yes to skip).
    # Running VMs must be stopped first or use --force.
    #
    # @example Convert a single VM
    #   pvectl template vm 100 --yes
    #
    # @example Convert multiple VMs
    #   pvectl template vm 100 101 102 --yes
    #
    # @example Force convert running VM (stops it first)
    #   pvectl template vm 100 --force --yes
    #
    # @example Convert specific disk only
    #   pvectl template vm 100 --disk scsi0 --yes
    #
    class TemplateVm
      include TemplateCommand

      # Registers the template command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Convert a resource to a template (irreversible)"
        cli.long_desc <<~HELP
          Convert a virtual machine or container into a Proxmox template.
          Templates are read-only base images used for linked cloning.

          WARNING: This operation is irreversible. Once converted, the resource
          cannot be converted back to a regular VM/container.

          EXAMPLES
            Convert a stopped VM to template:
              $ pvectl template vm 100 --yes

            Convert a running VM (stops it first):
              $ pvectl template vm 100 --force --yes

            Convert multiple VMs:
              $ pvectl template vm 100 101 102 --yes

            Convert a container:
              $ pvectl template ct 200 --yes

          NOTES
            The resource must be stopped before conversion. Use --force to
            automatically stop a running resource before converting.

            --yes skips the confirmation prompt. Without it, you will be
            asked to confirm the irreversible operation.

          SEE ALSO
            pvectl help clone           Create linked clones from templates
            pvectl help get templates   List existing templates
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :template do |c|
          c.desc "Skip confirmation prompt"
          c.switch [:yes, :y], negatable: false

          c.desc "Force stop running VM/container before conversion"
          c.switch [:force, :f], negatable: false

          c.desc "Filter by node name"
          c.flag [:node, :n], arg_name: "NODE"

          c.desc "Filter by selector (e.g., status=stopped,tags=base)"
          c.flag [:l, :selector], arg_name: "SELECTOR", multiple: true

          c.desc "Select all resources of this type"
          c.switch [:all, :A], negatable: false

          c.desc "Specific disk to convert (VM only, e.g., scsi0)"
          c.flag [:disk], arg_name: "DISK"

          c.action do |global_options, options, args|
            resource_type = args.shift

            exit_code = case resource_type
            when "vm"
              Commands::TemplateVm.execute(resource_type, args, options, global_options)
            when "container", "ct"
              Commands::TemplateContainer.execute(resource_type, args, options, global_options)
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
