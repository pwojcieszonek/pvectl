# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates container lifecycle operations.
    #
    # Handles execution of start/stop/shutdown/restart operations
    # with sync/async modes, error handling, and result collection.
    #
    # @example Basic usage
    #   service = ContainerLifecycle.new(ct_repo, task_repo)
    #   results = service.execute(:start, [ct1, ct2])
    #   results.each { |r| puts "#{r.container.vmid}: #{r.status_text}" }
    #
    class ContainerLifecycle
      SYNC_OPERATIONS = %i[start stop].freeze
      ASYNC_OPERATIONS = %i[shutdown restart].freeze
      ALL_OPERATIONS = (SYNC_OPERATIONS + ASYNC_OPERATIONS).freeze

      DEFAULT_TIMEOUT = 60

      # Creates a new ContainerLifecycle service.
      #
      # @param container_repository [Repositories::Container] Container repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, wait, fail_fast)
      def initialize(container_repository, task_repository, options = {})
        @container_repository = container_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes a lifecycle operation on a list of containers.
      #
      # @param operation [Symbol] Operation to execute
      # @param containers [Array<Models::Container>] Containers to operate on
      # @return [Array<Models::ContainerOperationResult>] Results for each container
      def execute(operation, containers)
        validate_operation!(operation)

        results = []
        containers.each do |container|
          result = execute_single(operation, container)
          results << result

          break if @options[:fail_fast] && result.failed?
        end
        results
      end

      private

      # Executes operation on a single container.
      #
      # @param operation [Symbol] Operation
      # @param container [Models::Container] Container
      # @return [Models::ContainerOperationResult] Result
      def execute_single(operation, container)
        task_upid = call_api(operation, container)

        if sync_mode?(operation)
          task = @task_repository.wait(task_upid, timeout: timeout)
          Models::ContainerOperationResult.new(
            container: container,
            operation: operation,
            task: task,
            success: task.successful?
          )
        else
          Models::ContainerOperationResult.new(
            container: container,
            operation: operation,
            task_upid: task_upid,
            success: :pending
          )
        end
      rescue StandardError => e
        Models::ContainerOperationResult.new(
          container: container,
          operation: operation,
          success: false,
          error: e.message
        )
      end

      # Calls the appropriate API method.
      #
      # @param operation [Symbol] Operation
      # @param container [Models::Container] Container
      # @return [String] Task UPID
      def call_api(operation, container)
        @container_repository.send(operation, container.vmid, container.node)
      end

      # Determines if operation should run in sync mode.
      #
      # @param operation [Symbol] Operation
      # @return [Boolean] true if sync mode
      def sync_mode?(operation)
        return false if @options[:async]
        return true if @options[:wait]

        SYNC_OPERATIONS.include?(operation)
      end

      # Returns configured timeout.
      #
      # @return [Integer] Timeout in seconds
      def timeout
        @options[:timeout] || DEFAULT_TIMEOUT
      end

      # Validates operation is supported.
      #
      # @param operation [Symbol] Operation
      # @raise [ArgumentError] if operation is not supported
      def validate_operation!(operation)
        return if ALL_OPERATIONS.include?(operation)

        raise ArgumentError, "Unknown operation: #{operation}. Valid: #{ALL_OPERATIONS.join(', ')}"
      end
    end
  end
end
