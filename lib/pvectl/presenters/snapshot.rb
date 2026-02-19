# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for VM/container snapshots.
    #
    # Defines column layout and formatting for snapshot table output.
    # Used by formatters to render snapshot data in various formats.
    #
    # Standard columns: VMID, NAME, CREATED, DESCRIPTION
    # Wide columns add: TYPE, VMSTATE, PARENT
    #
    # @example Using with formatter
    #   presenter = Snapshot.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(snapshots, presenter)
    #
    # @see Pvectl::Models::Snapshot Snapshot model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Snapshot < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME CREATED DESCRIPTION]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[TYPE VMSTATE PARENT]
      end

      # Converts Snapshot model to table row values.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.vmid.to_s,
          model.name,
          format_time(model.created_at),
          model.description || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        [
          model.resource_type&.to_s || "-",
          model.has_vmstate? ? "yes" : "no",
          model.parent || "-"
        ]
      end

      # Converts Snapshot model to hash for JSON/YAML output.
      #
      # @param model [Models::Snapshot] Snapshot model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        {
          "vmid" => model.vmid,
          "name" => model.name,
          "node" => model.node,
          "type" => model.resource_type&.to_s,
          "description" => model.description,
          "vmstate" => model.has_vmstate?,
          "parent" => model.parent,
          "created" => format_time(model.created_at)
        }
      end

      private

      # Formats time for display.
      #
      # @param time [Time, nil] time to format
      # @return [String] formatted time or "-" if nil
      def format_time(time)
        return "-" if time.nil?

        time.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end
end
