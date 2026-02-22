# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for volume operation results (set/edit).
    #
    # Formats VolumeOperationResult models for table/JSON/YAML output.
    #
    # @example Using with formatter
    #   presenter = VolumeOperationResult.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(results, presenter)
    #
    class VolumeOperationResult < OperationResult
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE RESOURCE ID DISK OPERATION STATUS MESSAGE]
      end

      # Converts result to table row values.
      #
      # @param model [Models::VolumeOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] row values
      def to_row(model, **_context)
        vol = model.volume
        [
          vol&.node || "-",
          vol&.resource_type || "-",
          vol&.resource_id&.to_s || "-",
          vol&.name || "-",
          model.operation&.to_s || "-",
          status_display(model),
          model.message
        ]
      end

      # Converts result to hash for JSON/YAML output.
      #
      # @param model [Models::VolumeOperationResult] result model
      # @return [Hash] hash representation
      def to_hash(model)
        vol = model.volume
        {
          "node" => vol&.node,
          "resource_type" => vol&.resource_type,
          "resource_id" => vol&.resource_id,
          "disk" => vol&.name,
          "operation" => model.operation&.to_s,
          "status" => model.status_text,
          "message" => model.message
        }
      end
    end
  end
end
