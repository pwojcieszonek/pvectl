# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for node time and timezone settings.
    #
    # Renders both the UTC timestamp and the node's local wall clock as
    # human-readable strings. Proxmox returns `localtime` as seconds-since-epoch
    # interpreted as if the node's wall clock were UTC, so we format it via
    # `Time.at(localtime).utc.strftime(...)` to preserve the node's view.
    #
    # @example Using with formatter
    #   presenter = TimeConfig.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(time_configs, presenter)
    #
    # @see Pvectl::Models::TimeConfig
    #
    class TimeConfig < Base
      # Date format for timestamp columns.
      TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S"

      # Returns column headers for table output.
      #
      # @return [Array<String>] column headers
      def columns
        ["NODE", "TIMEZONE", "TIME (UTC)", "LOCAL TIME"]
      end

      # Converts TimeConfig model to a table row.
      #
      # @param model [Models::TimeConfig] time configuration
      # @param _context [Hash] optional context (unused)
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.node_name || "-",
          model.timezone || "-",
          format_timestamp(model.time),
          format_timestamp(model.localtime)
        ]
      end

      # Converts TimeConfig model to a hash for JSON/YAML output.
      #
      # @param model [Models::TimeConfig] time configuration
      # @return [Hash{String => Object}] hash representation
      def to_hash(model)
        {
          "node" => model.node_name,
          "timezone" => model.timezone,
          "time" => model.time,
          "localtime" => model.localtime,
          "time_iso" => iso(model.time),
          "localtime_iso" => iso(model.localtime)
        }
      end

      private

      # Formats epoch seconds as a UTC-displayed string.
      #
      # Used for both the UTC `time` field and `localtime` (Proxmox encodes
      # the local wall clock as seconds-since-epoch interpreted as UTC, so the
      # same formatting produces the correct display in both cases).
      #
      # @param epoch [Integer, nil] seconds since 1970-01-01
      # @return [String] formatted timestamp or "-" when nil
      def format_timestamp(epoch)
        return "-" if epoch.nil?

        Time.at(epoch).utc.strftime(TIMESTAMP_FORMAT)
      end

      # ISO 8601 representation for JSON/YAML output.
      #
      # @param epoch [Integer, nil] seconds since 1970-01-01
      # @return [String, nil] ISO 8601 string or nil when epoch is nil
      def iso(epoch)
        return nil if epoch.nil?

        Time.at(epoch).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      end
    end
  end
end
