# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Handler for the `pvectl resize volume ct` command.
      #
      # Includes ResizeVolumeCommand for shared workflow and overrides
      # template methods with container-specific behavior.
      #
      # @example
      #   pvectl resize volume ct 200 rootfs +5G
      #
      class ResizeVolumeCt
        include ResizeVolumeCommand

        private

        # @return [String] human label for container resources
        def resource_label
          "container"
        end

        # @return [String] human label for container IDs
        def resource_id_label
          "CTID"
        end

        # @param connection [Connection] API connection
        # @return [Services::ResizeVolume] resize service with Container repository
        def build_resize_service(connection)
          repo = Pvectl::Repositories::Container.new(connection)
          Pvectl::Services::ResizeVolume.new(repository: repo)
        end

        # @return [Presenters::ContainerOperationResult] container result presenter
        def build_presenter
          Pvectl::Presenters::ContainerOperationResult.new
        end
      end
    end
  end
end
