# frozen_string_literal: true

module Pvectl
  module Commands
    # Container-specific lifecycle command hooks.
    #
    # Provides container repository, selector, service, and presenter
    # to ResourceLifecycleCommand's template methods.
    #
    # @example Usage
    #   class StartContainer
    #     include ContainerLifecycleCommand
    #     OPERATION = :start
    #   end
    #
    module ContainerLifecycleCommand
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
        %w[container ct]
      end

      # @return [String] human label for container resources
      def resource_label
        "container"
      end

      # @return [String] human label for container IDs
      def resource_id_label
        "CTID"
      end

      # Builds container repository.
      #
      # @param connection [Connection] API connection
      # @return [Repositories::Container] container repository
      def build_repository(connection)
        Pvectl::Repositories::Container.new(connection)
      end

      # Builds container lifecycle service.
      #
      # @param repo [Repositories::Container] container repository
      # @param task_repo [Repositories::Task] task repository
      # @param options [Hash] service options
      # @return [Services::ContainerLifecycle] container lifecycle service
      def build_service(repo, task_repo, options)
        Pvectl::Services::ContainerLifecycle.new(repo, task_repo, options)
      end

      # Builds container operation result presenter.
      #
      # @return [Presenters::ContainerOperationResult] presenter
      def build_presenter
        Pvectl::Presenters::ContainerOperationResult.new
      end

      # Builds container selector from strings.
      #
      # @param strings [Array<String>] selector strings
      # @return [Selectors::Container] parsed selector
      def build_selector(strings)
        Pvectl::Selectors::Container.parse_all(strings)
      end
    end
  end
end
