# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for physical disks on Proxmox nodes.
    #
    # Defines column layout and formatting for table output.
    # Standard columns show device, model, size, type, health, and usage.
    # Wide columns add serial, vendor, WWN, GPT, and mount status.
    #
    # @example Using with formatter
    #   presenter = Disk.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(disks, presenter)
    #
    # @see Pvectl::Models::PhysicalDisk PhysicalDisk model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Disk < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE DEVICE MODEL SIZE TYPE HEALTH USED]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[SERIAL VENDOR WWN GPT MOUNTED]
      end

      # Converts PhysicalDisk model to table row values.
      #
      # @param model [Models::PhysicalDisk] PhysicalDisk model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @disk = model
        [
          disk.node || "-",
          disk.devpath || "-",
          disk.model || "-",
          format_size,
          disk.type || "-",
          disk.health || "-",
          disk.used || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::PhysicalDisk] PhysicalDisk model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @disk = model
        [
          disk.serial || "-",
          disk.vendor || "-",
          disk.wwn || "-",
          format_boolean(disk.gpt),
          format_boolean(disk.mounted)
        ]
      end

      # Converts PhysicalDisk model to hash for JSON/YAML output.
      #
      # @param model [Models::PhysicalDisk] PhysicalDisk model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        @disk = model
        {
          "node" => disk.node,
          "device" => disk.devpath,
          "model" => disk.model,
          "size_bytes" => disk.size,
          "size_gb" => disk.size_gb,
          "type" => disk.type,
          "health" => disk.health,
          "used" => disk.used,
          "serial" => disk.serial,
          "vendor" => disk.vendor,
          "wwn" => disk.wwn,
          "gpt" => disk.gpt? || false,
          "mounted" => disk.mounted? || false
        }
      end

      private

      # @return [Models::PhysicalDisk] the current disk being presented
      attr_reader :disk

      # Formats disk size with appropriate unit (GB or TB).
      #
      # @return [String] formatted size (e.g., "500 GB" or "3.6 TB") or "-"
      def format_size
        gb = disk.size_gb
        return "-" if gb.nil?

        if gb >= 1024
          "#{(gb / 1024).round(1)} TB"
        else
          "#{gb.round(0).to_i} GB"
        end
      end

      # Formats boolean flag for display.
      #
      # @param value [Integer, nil] flag value (1/0/nil)
      # @return [String] "yes", "no", or "-"
      def format_boolean(value)
        return "-" if value.nil?

        value == 1 ? "yes" : "no"
      end
    end
  end
end
