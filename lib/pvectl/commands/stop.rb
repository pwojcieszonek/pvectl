# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl stop` command.
    #
    # Stops one or more virtual machines (hard stop).
    #
    # @example Stop a single VM
    #   pvectl stop vm 100
    #
    # @example Stop with JSON output
    #   pvectl stop vm 100 -o json
    #
    class Stop
      include VmLifecycleCommand

      OPERATION = :stop
    end
  end
end
