# frozen_string_literal: true

module Pvectl
  module Presenters
    # Base presenter for lifecycle operation results.
    #
    # Provides shared formatting helpers (status colors, task UPID, duration)
    # for subclasses like VmOperationResult and ContainerOperationResult.
    #
    # @abstract Subclass and implement columns, to_row, extra_values, to_hash.
    #
    class OperationResult < Base
      include Formatters::ColorSupport

      protected

      # Returns colored status display.
      #
      # @param model [Models::OperationResult] result model
      # @return [String] colored status
      def status_display(model)
        case model.status_text
        when "Success" then colorize(model.status_text, :green)
        when "Failed" then colorize(model.status_text, :red)
        when "Pending" then colorize(model.status_text, :yellow)
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
