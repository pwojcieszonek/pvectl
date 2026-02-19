# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl shutdown container` command.
    #
    # Shuts down one or more LXC containers gracefully.
    #
    # @example Shutdown a single container
    #   pvectl shutdown container 200
    #
    class ShutdownContainer
      include ContainerLifecycleCommand

      OPERATION = :shutdown
    end
  end
end
