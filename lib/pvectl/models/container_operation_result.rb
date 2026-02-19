# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the result of a lifecycle operation on a container.
    #
    # Extends OperationResult with container-specific attribute.
    #
    # @example Successful sync operation
    #   result = ContainerOperationResult.new(container: ct, task: task, success: task.successful?)
    #   result.container #=> #<Models::Container>
    #   result.successful? #=> true
    #
    class ContainerOperationResult < OperationResult
      # @return [Models::Container] The container this result is for
      attr_reader :container

      # Creates a new ContainerOperationResult.
      #
      # @param attrs [Hash] Result attributes including :container
      def initialize(attrs = {})
        super
        @container = @attributes[:container]
      end
    end
  end
end
