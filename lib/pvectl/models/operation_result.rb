# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the result of a lifecycle operation on a VM.
    #
    # Combines VM, task status, and error information into a single object
    # for consistent presentation of operation results.
    #
    # @example Successful sync operation
    #   result = OperationResult.new(vm: vm, task: task, success: task.successful?)
    #   result.successful? #=> true
    #   result.message #=> "OK"
    #
    # @example Async operation (pending)
    #   result = OperationResult.new(vm: vm, task_upid: upid, success: :pending)
    #   result.pending? #=> true
    #   result.message #=> "Task: UPID:pve1:..."
    #
    # @example Failed operation
    #   result = OperationResult.new(vm: vm, success: false, error: "Permission denied")
    #   result.failed? #=> true
    #   result.message #=> "Permission denied"
    #
    class OperationResult < Base
      # @return [Hash, nil] Generic resource info (for snapshot/backup operations)
      attr_reader :resource

      # @return [Symbol] The operation performed (:start, :stop, etc.)
      attr_reader :operation

      # @return [Models::Task, nil] The task (for completed sync operations)
      attr_reader :task

      # @return [String, nil] The task UPID (for async operations)
      attr_reader :task_upid

      # @return [Boolean, Symbol] true, false, or :pending
      attr_reader :success

      # @return [String, nil] Error message if operation failed
      attr_reader :error

      # Creates a new OperationResult.
      #
      # @param attrs [Hash] Result attributes
      def initialize(attrs = {})
        super(attrs)
        @resource = @attributes[:resource]
        @operation = @attributes[:operation]
        @task = @attributes[:task]
        @task_upid = @attributes[:task_upid]
        @success = @attributes[:success]
        @error = @attributes[:error]
      end

      # Checks if the operation was successful.
      #
      # @return [Boolean] true if success is true or task succeeded
      def successful?
        success == true || task&.successful?
      end

      # Checks if the operation failed.
      #
      # @return [Boolean] true if success is false or task failed
      def failed?
        success == false || task&.failed?
      end

      # Checks if the operation is still pending (async).
      #
      # @return [Boolean] true if success is :pending or task is pending
      def pending?
        success == :pending || task&.pending?
      end

      # Returns human-readable status.
      #
      # @return [String] "Pending", "Success", or "Failed"
      def status_text
        return "Pending" if pending?
        return "Success" if successful?

        "Failed"
      end

      # Returns the result message for display.
      #
      # Priority: error > task.exitstatus > task_upid > status_text
      #
      # @return [String] Result message
      def message
        return error if error
        return task.exitstatus if task
        return "Task: #{task_upid}" if task_upid

        status_text
      end
    end
  end
end
