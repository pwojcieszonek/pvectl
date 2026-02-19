# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl reset` command.
    #
    # Resets one or more virtual machines (hard reset).
    #
    # @example Reset a single VM
    #   pvectl reset vm 100
    #
    # @example Reset with JSON output
    #   pvectl reset vm 100 -o json
    #
    class Reset
      include VmLifecycleCommand

      OPERATION = :reset
    end
  end
end
