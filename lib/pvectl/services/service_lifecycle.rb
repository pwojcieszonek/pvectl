# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates systemd service lifecycle operations (start/stop/restart/reload)
    # on a Proxmox node.
    #
    # Wraps Repositories::Service to provide a uniform return shape suitable
    # for table/JSON/YAML formatting (Models::NodeOperationResult) and to
    # convert API errors into structured results instead of raising.
    #
    # @example Restarting a service
    #   service = ServiceLifecycle.new(service_repository: repo)
    #   result = service.execute(operation: :restart, node: "pve1", service: "pveproxy")
    #   result.successful? # => true
    #
    class ServiceLifecycle
      # Operations supported by the Proxmox services API.
      OPERATIONS = %i[start stop restart reload].freeze

      # Creates a new ServiceLifecycle orchestrator.
      #
      # @param service_repository [Repositories::Service] service repository
      def initialize(service_repository:)
        @service_repository = service_repository
      end

      # Executes a lifecycle operation on a single service.
      #
      # @param operation [Symbol] one of :start, :stop, :restart, :reload
      # @param node [String] node name
      # @param service [String] service identifier (e.g., "pveproxy")
      # @return [Models::NodeOperationResult] result with task UPID or error
      # @raise [ArgumentError] when operation is unknown
      def execute(operation:, node:, service:)
        validate_operation!(operation)

        begin
          upid = @service_repository.public_send(operation, node, service)
          build_result(
            operation: operation,
            node: node,
            service: service,
            task_upid: upid,
            success: :pending
          )
        rescue StandardError => e
          build_result(
            operation: operation,
            node: node,
            service: service,
            success: false,
            error: e.message
          )
        end
      end

      private

      # Validates operation is one of the supported actions.
      #
      # @param operation [Symbol] operation
      # @raise [ArgumentError] when not in OPERATIONS
      def validate_operation!(operation)
        return if OPERATIONS.include?(operation)

        raise ArgumentError,
              "Unknown service operation: #{operation}. Valid: #{OPERATIONS.join(', ')}"
      end

      # Builds a NodeOperationResult for the operation.
      #
      # @param operation [Symbol] operation
      # @param node [String] node name
      # @param service [String] service identifier
      # @param attrs [Hash] additional result attributes (task_upid, success, error)
      # @return [Models::NodeOperationResult]
      def build_result(operation:, node:, service:, **attrs)
        node_model = Models::Node.new(name: node)
        Models::NodeOperationResult.new(
          operation: operation,
          node_model: node_model,
          resource: { service: service, node: node },
          **attrs
        )
      end
    end
  end
end
