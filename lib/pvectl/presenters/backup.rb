# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for Backup models.
    #
    # Formats backups for table, wide, JSON, and YAML output.
    # Standard columns: VMID, TYPE, CREATED, SIZE, STORAGE, PROTECTED
    # Wide columns add: FORMAT, NOTES, VOLID
    #
    # @example Using with formatter
    #   presenter = Backup.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(backups, presenter)
    #
    # @see Pvectl::Models::Backup Backup model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Backup < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID TYPE CREATED SIZE STORAGE PROTECTED]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[FORMAT NOTES VOLID]
      end

      # Converts Backup model to table row values.
      #
      # @param model [Models::Backup] Backup model
      # @param context [Hash] optional context
      # @return [Array] row values matching columns order
      def to_row(model, **_context)
        [
          model.vmid,
          format_type(model.resource_type),
          format_time(model.created_at),
          model.human_size,
          model.storage,
          format_protected(model.protected?)
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Backup] Backup model
      # @param context [Hash] optional context
      # @return [Array] extra values matching extra_columns order
      def extra_values(model, **_context)
        [
          model.format,
          truncate(model.notes, 30),
          model.volid
        ]
      end

      # Converts Backup model to hash for JSON/YAML output.
      #
      # @param model [Models::Backup] Backup model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        {
          "vmid" => model.vmid,
          "type" => format_type(model.resource_type),
          "volid" => model.volid,
          "storage" => model.storage,
          "node" => model.node,
          "size" => model.size,
          "size_human" => model.human_size,
          "created_at" => model.created_at&.iso8601,
          "format" => model.format,
          "notes" => model.notes,
          "protected" => model.protected?
        }
      end

      private

      # Formats resource type for display.
      #
      # @param resource_type [Symbol, nil] :qemu or :lxc
      # @return [String] formatted type
      def format_type(resource_type)
        case resource_type
        when :qemu then "qemu"
        when :lxc then "lxc"
        else "-"
        end
      end

      # Formats time for display.
      #
      # @param time [Time, nil] time to format
      # @return [String] formatted time or "-" if nil
      def format_time(time)
        return "-" if time.nil?

        time.strftime("%Y-%m-%d %H:%M:%S")
      end

      # Formats protected status for display.
      #
      # @param protected [Boolean] protection status
      # @return [String] "yes" or "no"
      def format_protected(protected_status)
        protected_status ? "yes" : "no"
      end

      # Truncates text to specified length.
      #
      # @param text [String, nil] text to truncate
      # @param max_length [Integer] maximum length
      # @return [String, nil] truncated text or nil
      def truncate(text, max_length)
        return nil if text.nil?
        return text if text.length <= max_length

        "#{text[0, max_length - 3]}..."
      end
    end
  end
end
