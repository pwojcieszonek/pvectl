# frozen_string_literal: true

require "tty-table"

module Pvectl
  module Formatters
    # Formats data as a table using tty-table gem.
    #
    # For collections: renders standard horizontal table with headers.
    # For single resources (describe): renders vertical key-value layout.
    #
    # @example Table output for collection
    #   NAME    STATUS   NODE
    #   vm-100  running  pve1
    #   vm-101  stopped  pve2
    #
    # @example Vertical output for single resource (describe)
    #   Name:     vm-100
    #   Status:   running
    #   Node:     pve1
    #
    # @see Pvectl::Formatters::Wide for extended column output
    #
    class Table < Base
      # Formats data as table output.
      #
      # @param data [Array, Object] collection of models or single model
      # @param presenter [Presenters::Base] presenter for column/row definitions
      # @param color_enabled [Boolean] whether to apply color formatting
      # @param describe [Boolean] whether this is a describe command (single resource)
      # @param context [Hash] additional context passed to presenter
      # @return [String] formatted table string
      def format(data, presenter, color_enabled: true, describe: false, **context)
        pastel = ColorSupport.pastel(explicit_flag: color_enabled)

        if describe || !collection?(data)
          format_describe(data, presenter, pastel)
        else
          format_table(data, presenter, pastel, **context)
        end
      end

      private

      # Formats collection as horizontal table.
      #
      # @param data [Array] collection of models
      # @param presenter [Presenters::Base] presenter
      # @param pastel [Pastel] pastel instance for coloring
      # @param context [Hash] context passed to presenter
      # @return [String] formatted table
      def format_table(data, presenter, pastel, **context)
        headers = presenter.columns
        rows = data.map do |model|
          row = presenter.to_row(model, **context)
          colorize_row(row, headers, pastel)
        end

        render_table(headers, rows)
      end

      # Formats single resource as vertical key-value layout.
      # Supports nested Hashes (sections) and Arrays of Hashes (tables).
      #
      # @param model [Object] single model
      # @param presenter [Presenters::Base] presenter
      # @param pastel [Pastel] pastel instance for coloring
      # @return [String] formatted vertical layout
      def format_describe(model, presenter, pastel)
        hash = presenter.to_description(model)
        format_describe_hash(hash, pastel, indent: 0)
      end

      # Colorizes status columns in a row.
      #
      # @param row [Array] row values
      # @param headers [Array<String>] column headers
      # @param pastel [Pastel] pastel instance
      # @return [Array] row with colorized values
      def colorize_row(row, headers, pastel)
        row.each_with_index.map do |value, idx|
          header = headers[idx].to_s.downcase
          if header == "status"
            ColorSupport.colorize_status(value, pastel)
          else
            normalize_nil(value)
          end
        end
      end

      # Recursively formats a hash for describe output.
      #
      # @param hash [Hash] hash to format
      # @param pastel [Pastel] pastel instance
      # @param indent [Integer] current indentation level
      # @return [String] formatted output
      def format_describe_hash(hash, pastel, indent: 0)
        return "-" if hash.nil?

        lines = []
        prefix = "  " * indent

        # Calculate max key length for alignment (only for non-nested values)
        simple_keys = hash.select { |_, v| !v.is_a?(Hash) && !(v.is_a?(Array) && v.first.is_a?(Hash)) && !v.to_s.include?("\n") }
        max_key_length = simple_keys.keys.map { |k| k.to_s.length }.max || 0

        hash.each do |key, value|
          human_key = humanize_key(key)

          if value.is_a?(Hash)
            # Nested section
            lines << ""
            lines << "#{prefix}#{human_key}:"
            lines << format_describe_hash(value, pastel, indent: indent + 1)
          elsif value.is_a?(Array) && !value.empty? && value.first.is_a?(Hash)
            # Array of hashes -> inline table
            lines << ""
            lines << "#{prefix}#{human_key}:"
            lines << format_describe_table(value, indent: indent + 1)
          elsif value.is_a?(Array) && value.empty?
            # Empty array -> show as "-"
            formatted_key = "#{human_key}:".ljust(max_key_length + 2)
            lines << "#{prefix}#{formatted_key}-"
          else
            formatted_value = format_describe_value(value, key.to_s, pastel)
            if formatted_value.include?("\n")
              # Multi-line value: render as block section
              lines << ""
              lines << "#{prefix}#{human_key}:"
              formatted_value.each_line do |line|
                lines << "#{prefix}  #{line.chomp}"
              end
            else
              # Simple key-value
              formatted_key = "#{human_key}:".ljust(max_key_length + 2)
              lines << "#{prefix}#{formatted_key}#{formatted_value}"
            end
          end
        end

        lines.join("\n").sub(/\A\n+/, "").rstrip
      end

      # Formats array of hashes as inline table.
      #
      # @param array [Array<Hash>] array of hashes
      # @param indent [Integer] indentation level
      # @return [String] formatted table
      def format_describe_table(array, indent: 0)
        return "  " * indent + "-" if array.empty?

        prefix = "  " * indent
        headers = array.first.keys.map { |k| k.to_s.upcase }
        rows = array.map { |item| item.values.map(&:to_s) }

        # Calculate column widths
        widths = headers.each_with_index.map do |h, i|
          [h.length, *rows.map { |r| r[i]&.length || 0 }].max
        end

        lines = []
        # Header
        header_line = headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join("  ")
        lines << "#{prefix}#{header_line}"

        # Rows
        rows.each do |row|
          row_line = row.each_with_index.map { |v, i| (v || "-").ljust(widths[i]) }.join("  ")
          lines << "#{prefix}#{row_line}"
        end

        lines.join("\n")
      end

      # Formats a value for describe output.
      #
      # @param value [Object] value to format
      # @param key [String] key name (used for status detection)
      # @param pastel [Pastel] pastel instance
      # @return [String] formatted value
      def format_describe_value(value, key, pastel)
        return "-" if value.nil?

        if key.downcase == "status"
          ColorSupport.colorize_status(value, pastel)
        else
          value.to_s
        end
      end

      # Converts snake_case or kebab-case key to Title Case.
      # Preserves already-formatted keys (e.g., "CPU", "DNS").
      #
      # @param key [String, Symbol] key to humanize
      # @return [String] humanized key
      def humanize_key(key)
        str = key.to_s
        # If the key is already formatted (contains spaces or is all caps), return as-is
        return str if str.include?(" ") || str == str.upcase

        str.split(/[_-]/).map(&:capitalize).join(" ")
      end

      # Renders table using tty-table.
      #
      # Uses :basic renderer for clean kubectl-like output (no borders).
      # Handles non-TTY environments gracefully by rescuing ioctl errors.
      #
      # @param headers [Array<String>] column headers
      # @param rows [Array<Array>] row data
      # @return [String] rendered table
      def render_table(headers, rows)
        table = TTY::Table.new(header: headers, rows: rows)
        table.render(:basic, padding: [0, 2]) || headers.join("\t")
      rescue NoMethodError
        # TTY::Screen may call ioctl on non-TTY streams (e.g., StringIO in tests)
        # Fall back to simple tab-separated output
        ([headers] + rows).map { |row| row.join("\t") }.join("\n")
      end
    end
  end
end
