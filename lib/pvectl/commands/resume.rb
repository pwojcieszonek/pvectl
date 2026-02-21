# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl resume` command.
    #
    # Resumes one or more suspended virtual machines.
    #
    # @example Resume a single VM
    #   pvectl resume vm 100
    #
    # @example Resume with JSON output
    #   pvectl resume vm 100 -o json
    #
    class Resume
      include VmLifecycleCommand

      # Registers the resume command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Resume suspended virtual machines"
        cli.long_desc <<~HELP
          Resume one or more suspended (hibernated) virtual machines. Restores
          the VM's memory state from disk and continues execution.

          Only available for VMs. Containers do not support resume.

          EXAMPLES
            Resume a suspended VM:
              $ pvectl resume vm 100

            Resume all suspended VMs:
              $ pvectl resume vm --all -l status=suspended --yes

          SEE ALSO
            pvectl help suspend         Suspend (hibernate) VMs
            pvectl help start           Start a stopped VM (no state restore)
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :resume do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = execute(resource_type, resource_ids, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :resume
    end
  end
end
