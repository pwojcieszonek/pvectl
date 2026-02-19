# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for container lifecycle operation results.
    #
    # Formats ContainerOperationResult models for table/JSON/YAML output.
    #
    # @example Using with formatter
    #   presenter = ContainerOperationResult.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(results, presenter)
    #
    class ContainerOperationResult < OperationResult
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[CTID NAME NODE STATUS MESSAGE]
      end

      # Returns additional columns for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[TASK DURATION]
      end

      # Converts result to table row values.
      #
      # @param model [Models::ContainerOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] row values
      def to_row(model, **_context)
        [
          model.container.vmid.to_s,
          display_name(model.container),
          model.container.node,
          status_display(model),
          model.message
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::ContainerOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values
      def extra_values(model, **_context)
        [
          task_upid(model),
          duration_display(model)
        ]
      end

      # Converts result to hash for JSON/YAML output.
      #
      # @param model [Models::ContainerOperationResult] result model
      # @return [Hash] hash representation
      def to_hash(model)
        {
          "ctid" => model.container.vmid,
          "name" => model.container.name,
          "node" => model.container.node,
          "status" => model.status_text,
          "message" => model.message,
          "task_upid" => model.task_upid || model.task&.upid
        }
      end

      private

      # Returns display name for container.
      #
      # @param container [Models::Container] container model
      # @return [String] display name
      def display_name(container)
        container.name || "CT-#{container.vmid}"
      end
    end
  end
end
