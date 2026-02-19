# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl stop container` command.
    #
    # Stops one or more LXC containers (hard stop).
    #
    # @example Stop a single container
    #   pvectl stop container 200
    #
    class StopContainer
      include ContainerLifecycleCommand

      OPERATION = :stop
    end
  end
end
