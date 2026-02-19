# frozen_string_literal: true

module Pvectl
  module Commands
    # VM-specific lifecycle command hooks.
    #
    # Provides VM repository, selector, service, and presenter
    # to ResourceLifecycleCommand's template methods.
    #
    # @example Usage
    #   class Start
    #     include VmLifecycleCommand
    #     OPERATION = :start
    #   end
    #
    module VmLifecycleCommand
      include ResourceLifecycleCommand

      # Extends the including class with ClassMethods from ResourceLifecycleCommand.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(ResourceLifecycleCommand::ClassMethods)
      end

      private

      # @return [Array<String>] supported resource types
      def supported_resources
        %w[vm]
      end

      # @return [String] human label for VM resources
      def resource_label
        "VM"
      end

      # @return [String] human label for VM IDs
      def resource_id_label
        "VMID"
      end

      # Builds VM repository.
      #
      # @param connection [Connection] API connection
      # @return [Repositories::Vm] VM repository
      def build_repository(connection)
        Pvectl::Repositories::Vm.new(connection)
      end

      # Builds VM lifecycle service.
      #
      # @param repo [Repositories::Vm] VM repository
      # @param task_repo [Repositories::Task] task repository
      # @param options [Hash] service options
      # @return [Services::VmLifecycle] VM lifecycle service
      def build_service(repo, task_repo, options)
        Pvectl::Services::VmLifecycle.new(repo, task_repo, options)
      end

      # Builds VM operation result presenter.
      #
      # @return [Presenters::VmOperationResult] presenter
      def build_presenter
        Pvectl::Presenters::VmOperationResult.new
      end

      # Builds VM selector from strings.
      #
      # @param strings [Array<String>] selector strings
      # @return [Selectors::Vm] parsed selector
      def build_selector(strings)
        Pvectl::Selectors::Vm.parse_all(strings)
      end
    end
  end
end
