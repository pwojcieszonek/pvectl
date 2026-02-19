# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl start` command.
    #
    # Starts one or more virtual machines.
    #
    # @example Start a single VM
    #   pvectl start vm 100
    #
    # @example Start with JSON output
    #   pvectl start vm 100 -o json
    #
    class Start
      include VmLifecycleCommand

      OPERATION = :start
    end
  end
end
