# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates VM lifecycle operations.
    #
    # Handles execution of start/stop/shutdown/restart/reset/suspend/resume
    # operations with sync/async modes, error handling, and result collection.
    #
    # @example Basic usage
    #   service = VmLifecycle.new(vm_repo, task_repo)
    #   results = service.execute(:start, [vm1, vm2])
    #   results.each { |r| puts "#{r.vm.vmid}: #{r.status_text}" }
    #
    class VmLifecycle
      SYNC_OPERATIONS = %i[start stop reset resume].freeze
      ASYNC_OPERATIONS = %i[shutdown restart suspend].freeze
      ALL_OPERATIONS = (SYNC_OPERATIONS + ASYNC_OPERATIONS).freeze

      DEFAULT_TIMEOUT = 60

      # Creates a new VmLifecycle service.
      #
      # @param vm_repository [Repositories::Vm] VM repository
      # @param task_repository [Repositories::Task] Task repository
      # @param options [Hash] Options (timeout, async, wait, fail_fast)
      def initialize(vm_repository, task_repository, options = {})
        @vm_repository = vm_repository
        @task_repository = task_repository
        @options = options
      end

      # Executes a lifecycle operation on a list of VMs.
      #
      # @param operation [Symbol] Operation to execute
      # @param vms [Array<Models::Vm>] VMs to operate on
      # @return [Array<Models::OperationResult>] Results for each VM
      def execute(operation, vms)
        validate_operation!(operation)

        results = []
        vms.each do |vm|
          result = execute_single(operation, vm)
          results << result

          break if @options[:fail_fast] && result.failed?
        end
        results
      end

      private

      # Executes operation on a single VM.
      #
      # @param operation [Symbol] Operation
      # @param vm [Models::Vm] VM
      # @return [Models::OperationResult] Result
      def execute_single(operation, vm)
        task_upid = call_api(operation, vm)

        if sync_mode?(operation)
          task = @task_repository.wait(task_upid, timeout: timeout)
          Models::VmOperationResult.new(
            vm: vm,
            operation: operation,
            task: task,
            success: task.successful?
          )
        else
          Models::VmOperationResult.new(
            vm: vm,
            operation: operation,
            task_upid: task_upid,
            success: :pending
          )
        end
      rescue StandardError => e
        Models::VmOperationResult.new(
          vm: vm,
          operation: operation,
          success: false,
          error: e.message
        )
      end

      # Calls the appropriate API method.
      #
      # @param operation [Symbol] Operation
      # @param vm [Models::Vm] VM
      # @return [String] Task UPID
      def call_api(operation, vm)
        @vm_repository.send(operation, vm.vmid, vm.node)
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
