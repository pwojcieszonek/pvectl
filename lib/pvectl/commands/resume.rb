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

      OPERATION = :resume
    end
  end
end
