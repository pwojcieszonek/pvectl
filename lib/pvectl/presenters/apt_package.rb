# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for APT packages (pending updates and installed versions).
    #
    # Standard columns highlight the upgrade path; wide columns add metadata
    # useful when triaging updates.
    #
    # @example Using with formatter
    #   presenter = AptPackage.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(packages, presenter)
    #
    # @see Pvectl::Models::AptPackage AptPackage model
    #
    class AptPackage < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE PACKAGE CURRENT AVAILABLE ORIGIN]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[ARCH SECTION PRIORITY DESCRIPTION]
      end

      # Converts AptPackage model to table row values.
      #
      # @param model [Models::AptPackage] package model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.node || "-",
          model.package || "-",
          model.old_version || "-",
          model.version || "-",
          model.origin || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::AptPackage] package model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        [
          model.arch || "-",
          model.section || "-",
          model.priority || "-",
          truncate(model.description, 60)
        ]
      end

      # Converts AptPackage model to hash for JSON/YAML output.
      #
      # @param model [Models::AptPackage] package model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        {
          "node" => model.node,
          "package" => model.package,
          "title" => model.title,
          "current_version" => model.old_version,
          "available_version" => model.version,
          "origin" => model.origin,
          "arch" => model.arch,
          "section" => model.section,
          "priority" => model.priority,
          "description" => model.description,
          "notify_status" => model.notify_status,
          "current_state" => model.current_state,
          "manager_version" => model.manager_version,
          "running_kernel" => model.running_kernel
        }
      end

      private

      # Truncates text to fit in a column.
      #
      # @param text [String, nil] text to truncate
      # @param length [Integer] maximum length
      # @return [String] truncated text or "-"
      def truncate(text, length)
        return "-" if text.nil? || text.empty?
        return text if text.length <= length

        "#{text[0, length - 1]}…"
      end
    end
  end
end
