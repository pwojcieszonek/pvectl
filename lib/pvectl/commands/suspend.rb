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

      OPERATION = :suspend
    end
  end
end
