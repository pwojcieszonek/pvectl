# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl shutdown` command.
    #
    # Shuts down one or more virtual machines gracefully (ACPI).
    #
    # @example Shutdown a single VM
    #   pvectl shutdown vm 100
    #
    # @example Shutdown with sync mode
    #   pvectl shutdown vm 100 --wait
    #
    class Shutdown
      include VmLifecycleCommand

      OPERATION = :shutdown
    end
  end
end
