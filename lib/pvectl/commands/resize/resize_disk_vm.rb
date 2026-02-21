# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Handler for the `pvectl resize disk vm` command.
      #
      # Includes ResizeDiskCommand for shared workflow and overrides
      # template methods with VM-specific behavior.
      #
      # @example
      #   pvectl resize disk vm 100 scsi0 +10G
      #
      class ResizeDiskVm
        include ResizeDiskCommand

        private

        # @return [String] human label for VM resources
        def resource_label
          "VM"
        end

        # @return [String] human label for VM IDs
        def resource_id_label
          "VMID"
        end

        # @param connection [Connection] API connection
        # @return [Services::ResizeDisk] resize service with VM repository
        def build_resize_service(connection)
          repo = Pvectl::Repositories::Vm.new(connection)
          Pvectl::Services::ResizeDisk.new(repository: repo)
        end

        # @return [Presenters::VmOperationResult] VM result presenter
        def build_presenter
          Pvectl::Presenters::VmOperationResult.new
        end
      end
    end
  end
end
