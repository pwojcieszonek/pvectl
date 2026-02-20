# frozen_string_literal: true

module Pvectl
  module Commands
    # Delete-specific functionality built on IrreversibleCommand.
    #
    # Adds delete-specific behavior:
    # - Confirmation message mentioning disk destruction
    # - --keep-disks and --purge options in service_options
    # - Delegates to Services::ResourceDelete
    #
    # @example Including in a command class
    #   class DeleteVm
    #     include DeleteCommand
    #     RESOURCE_TYPE = :vm
    #     SUPPORTED_RESOURCES = %w[vm].freeze
    #   end
    #
    module DeleteCommand
      include IrreversibleCommand

      # Hook called when module is included.
      #
      # @param base [Class] the class including this module
      def self.included(base)
        base.extend(IrreversibleCommand::ClassMethods)
      end

      private

      # Returns confirmation message for delete operation.
      #
      # @param resources [Array] resources to delete
      # @return [String] confirmation message
      def confirm_message(resources)
        type_name = resource_type_symbol == :vm ? "VM" : "container"
        type_plural = resource_type_symbol == :vm ? "VMs" : "containers"

        if resources.size == 1
          r = resources.first
          "You are about to delete #{type_name} #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node}."
        else
          lines = ["You are about to delete #{resources.size} #{type_plural}:"]
          resources.each { |r| lines << "  - #{r.vmid} (#{r.name || 'unnamed'}) on #{r.node}" }
          lines.join("\n")
        end
      end

      # Returns irreversibility warning for delete.
      #
      # @return [String] warning text
      def irreversibility_warning
        type_plural = resource_type_symbol == :vm ? "VMs" : "containers"
        if @options[:"keep-disks"]
          "This action is IRREVERSIBLE. Disks will be preserved."
        else
          "This action is IRREVERSIBLE and will destroy the #{type_plural} and their disks."
        end
      end

      # Confirms delete operation — always required (uses --yes flag, not --force).
      #
      # @param resources [Array] Resources to delete
      # @return [Boolean] true if operation should proceed
      def confirm_operation(resources)
        return true if @options[:yes]

        $stdout.puts confirm_message(resources)
        $stdout.puts ""
        $stdout.puts irreversibility_warning
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Performs the delete service call.
      #
      # @param resources [Array] resources to delete
      # @param connection [Connection] API connection
      # @return [Array<Models::OperationResult>] results
      def perform_service_call(resources, connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        container_repo = Pvectl::Repositories::Container.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::ResourceDelete.new(
          vm_repository: vm_repo,
          container_repository: container_repo,
          task_repository: task_repo,
          options: service_options
        )

        service.execute(resource_type_symbol, resources)
      end

      # Builds presenter for delete results.
      #
      # @return [Presenters::Base] presenter
      def build_presenter
        if resource_type_symbol == :vm
          Pvectl::Presenters::VmOperationResult.new
        else
          Pvectl::Presenters::ContainerOperationResult.new
        end
      end

      # Builds service options with delete-specific flags.
      #
      # @return [Hash] service options
      def service_options
        opts = super
        opts[:keep_disks] = true if @options[:"keep-disks"]
        opts[:purge] = true if @options[:purge]
        opts
      end
    end
  end
end
