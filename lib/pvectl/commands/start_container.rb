# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl start container` command.
    #
    # Starts one or more LXC containers.
    #
    # @example Start a single container
    #   pvectl start container 200
    #
    class StartContainer
      include ContainerLifecycleCommand

      OPERATION = :start
    end
  end
end
