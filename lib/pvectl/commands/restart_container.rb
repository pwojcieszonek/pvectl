# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl restart container` command.
    #
    # Restarts one or more LXC containers (reboot).
    #
    # @example Restart a single container
    #   pvectl restart container 200
    #
    class RestartContainer
      include ContainerLifecycleCommand

      OPERATION = :restart
    end
  end
end
