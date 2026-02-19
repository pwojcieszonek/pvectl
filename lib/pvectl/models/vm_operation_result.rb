# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the result of a lifecycle operation on a VM.
    #
    # Extends OperationResult with VM-specific attribute.
    #
    # @example Successful sync operation
    #   result = VmOperationResult.new(vm: vm, task: task, success: task.successful?)
    #   result.vm #=> #<Models::Vm>
    #   result.successful? #=> true
    #
    class VmOperationResult < OperationResult
      # @return [Models::Vm] The VM this result is for
      attr_reader :vm

      # Creates a new VmOperationResult.
      #
      # @param attrs [Hash] Result attributes including :vm
      def initialize(attrs = {})
        super
        @vm = @attributes[:vm]
      end
    end
  end
end
