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
