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

      # @return [String, nil] optional info message describing the successful
      #   outcome (e.g., "Wake-on-LAN packet sent (MAC: AA:BB:CC:DD:EE:FF)")
      attr_reader :info

      # Creates a new NodeOperationResult.
      #
      # @param attrs [Hash] Result attributes including :node_model
      def initialize(attrs = {})
        super
        @node_model = @attributes[:node_model]
        @info = @attributes[:message]
      end

      # Returns the result message for display.
      #
      # On success, prefers the optional `:message` attribute (set by services
      # that want to surface an outcome detail like a MAC address). Otherwise
      # falls back to the generic OperationResult logic (error / task / status).
      #
      # @return [String]
      def message
        return @info if successful? && @info

        super
      end
    end
  end
end
