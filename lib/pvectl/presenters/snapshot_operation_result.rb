# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for snapshot operation results.
    #
    # Formats OperationResult models from snapshot operations for table/JSON/YAML output.
    # Unlike OperationResult presenter, this handles resource hash instead of VM model.
    #
    # @example Using with formatter
    #   presenter = SnapshotOperationResult.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(results, presenter)
    #
    class SnapshotOperationResult < Base
      include Formatters::ColorSupport

      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME TYPE NODE STATUS MESSAGE]
      end

      # Returns additional columns for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[TASK DURATION]
      end

      # Converts result to table row values.
      #
      # @param model [Models::OperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] row values
      def to_row(model, **_context)
        resource = model.resource || {}
        [
          resource[:vmid].to_s,
          resource[:name] || "-",
          resource[:type]&.to_s || "-",
          resource[:node] || "-",
          status_display(model),
          model.message
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::OperationResult] result model
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
      # @param model [Models::OperationResult] result model
      # @return [Hash] hash representation
      def to_hash(model)
        resource = model.resource || {}
        {
          "vmid" => resource[:vmid],
          "name" => resource[:name],
          "type" => resource[:type]&.to_s,
          "node" => resource[:node],
          "operation" => model.operation&.to_s,
          "status" => model.status_text,
          "message" => model.message,
          "task_upid" => model.task_upid || model.task&.upid
        }
      end

      private

      # Returns colored status display.
      #
      # @param model [Models::OperationResult] result model
      # @return [String] colored status
      def status_display(model)
        case model.status_text
        when "Success" then colorize(model.status_text, :green)
        when "Failed" then colorize(model.status_text, :red)
        when "Pending" then colorize(model.status_text, :yellow)
        when "Partial" then colorize(model.status_text, :bright_yellow)
        else model.status_text
        end
      end

      # Returns task UPID or dash.
      #
      # @param model [Models::OperationResult] result model
      # @return [String] UPID or "-"
      def task_upid(model)
        model.task_upid || model.task&.upid || "-"
      end

      # Returns formatted duration.
      #
      # @param model [Models::OperationResult] result model
      # @return [String] duration or "-"
      def duration_display(model)
        duration = model.task&.duration
        return "-" unless duration

        "#{duration.to_f.round(1)}s"
      end

      # Colorizes text using Pastel.
      #
      # @param text [String] text to colorize
      # @param color [Symbol] color name (:green, :red, :yellow)
      # @return [String] colored text
      def colorize(text, color)
        pastel = Formatters::ColorSupport.pastel(explicit_flag: nil)
        pastel.public_send(color, text)
      end
    end
  end
end
