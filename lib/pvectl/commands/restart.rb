# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl restart` command.
    #
    # Restarts one or more virtual machines (reboot).
    #
    # @example Restart a single VM
    #   pvectl restart vm 100
    #
    # @example Restart with sync mode
    #   pvectl restart vm 100 --wait
    #
    class Restart
      include VmLifecycleCommand

      OPERATION = :restart
    end
  end
end
