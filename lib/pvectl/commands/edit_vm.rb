# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit vm` command.
    #
    # Includes EditResourceCommand for shared workflow and overrides
    # template methods with VM-specific behavior.
    #
    # @example Basic usage
    #   pvectl edit vm 100
    #
    # @example With custom editor
    #   pvectl edit vm 100 --editor nano
    #
    # @example Dry-run mode
    #   pvectl edit vm 100 --dry-run
    #
    class EditVm
      include EditResourceCommand

      private

      # @return [String] human label for VM resources
      def resource_label
        "VM"
      end

      # @return [String] human label for VM IDs
      def resource_id_label
        "VMID"
      end

      # Builds execution parameters from a VM ID.
      #
      # @param resource_id [Integer] VMID
      # @return [Hash] parameters for the edit service
      def execute_params(resource_id)
        { vmid: resource_id }
      end

      # Builds the VM edit service.
      #
      # @param connection [Connection] API connection
      # @return [Services::EditVm] VM edit service
      def build_edit_service(connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        Pvectl::Services::EditVm.new(
          vm_repository: vm_repo,
          editor_session: build_editor_session,
          options: service_options
        )
      end
    end
  end
end
