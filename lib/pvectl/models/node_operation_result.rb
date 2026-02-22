# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the result of a set/edit operation on a node.
    #
    # Extends OperationResult with node-specific attribute.
    #
    # @example Successful set operation
    #   result = NodeOperationResult.new(node_model: node, operation: :set, success: true)
    #   result.node_model #=> #<Models::Node>
    #   result.successful? #=> true
    #
    class NodeOperationResult < OperationResult
      # @return [Models::Node, nil] The node this result is for
      attr_reader :node_model

      # Creates a new NodeOperationResult.
      #
      # @param attrs [Hash] Result attributes including :node_model
      def initialize(attrs = {})
        super
        @node_model = @attributes[:node_model]
      end
    end
  end
end
