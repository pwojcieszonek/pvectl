# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl suspend` command.
    #
    # Suspends one or more virtual machines (hibernate).
    #
    # @example Suspend a single VM
    #   pvectl suspend vm 100
    #
    # @example Suspend with sync mode
    #   pvectl suspend vm 100 --wait
    #
    class Suspend
      include VmLifecycleCommand

      # Registers the suspend command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Suspend virtual machines (hibernate)"
        cli.long_desc <<~HELP
          Suspend (hibernate) one or more virtual machines. Saves the VM's
          memory state to disk and stops it. The VM can be resumed later
          with 'pvectl resume'.

          Only available for VMs. Containers do not support suspend.

          EXAMPLES
            Suspend a VM:
              $ pvectl suspend vm 100

            Suspend all running VMs on a node:
              $ pvectl suspend vm --all --node pve1 -l status=running --yes

          NOTES
            Suspend saves the full memory state to disk, which may take time
            for VMs with large memory allocations.

            Not available for containers.

          SEE ALSO
            pvectl help resume          Resume suspended VMs
            pvectl help shutdown        Graceful shutdown (no state saved)
        HELP
        cli.arg_name "RESOURCE_TYPE [ID...]"
        cli.command :suspend do |c|
          SharedFlags.lifecycle(c)

          c.action do |global_options, options, args|
            resource_type = args.shift
            resource_ids = args
            exit_code = execute(resource_type, resource_ids, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      OPERATION = :suspend
    end
  end
end
