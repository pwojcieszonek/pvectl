# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl move disk ct` command.
    #
    # Moves a container volume (rootfs / mpN) to a different storage on the
    # same node. The --format flag is rejected because the LXC move_volume
    # API does not accept a format.
    #
    # @example Move rootfs of container 200 to storage2
    #   pvectl move disk ct 200 rootfs --target storage2
    #
    class MoveDiskContainer
      include MoveDiskCommand

      RESOURCE_TYPE = :container
      SUPPORTED_RESOURCES = %w[container ct].freeze
    end
  end
end
