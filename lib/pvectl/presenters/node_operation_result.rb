# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for node operation results (set/edit).
    #
    # Formats NodeOperationResult models for table/JSON/YAML output.
    #
    # @example Using with formatter
    #   presenter = NodeOperationResult.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(results, presenter)
    #
    class NodeOperationResult < OperationResult
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE OPERATION STATUS MESSAGE]
      end

      # Converts result to table row values.
      #
      # @param model [Models::NodeOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] row values
      def to_row(model, **_context)
        [
          model.node_model&.name || "-",
          model.operation&.to_s || "-",
          status_display(model),
          model.message
        ]
      end

      # Converts result to hash for JSON/YAML output.
      #
      # @param model [Models::NodeOperationResult] result model
      # @return [Hash] hash representation
      def to_hash(model)
        {
          "node" => model.node_model&.name,
          "operation" => model.operation&.to_s,
          "status" => model.status_text,
          "message" => model.message
        }
      end
    end
  end
end
