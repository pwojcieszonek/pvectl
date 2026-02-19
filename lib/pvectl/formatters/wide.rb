# frozen_string_literal: true

require "tty-table"

module Pvectl
  module Formatters
    # Formats data as a wide table with extended columns.
    #
    # For collections: uses wide_columns and to_wide_row from presenter.
    # For single resources (describe): delegates to Table (no wide variant).
    #
    # @example Wide table output
    #   NAME    STATUS   NODE   MEMORY   CPU   UPTIME
    #   vm-100  running  pve1   2048     2     3d 5h
    #
    # @see Pvectl::Formatters::Table for standard table output
    # @see Pvectl::Presenters::Base#wide_columns for wide column definitions
    #
    class Wide < Base
      # Formats data as wide table output.
      #
      # @param data [Array, Object] collection of models or single model
      # @param presenter [Presenters::Base] presenter for column/row definitions
      # @param color_enabled [Boolean] whether to apply color formatting
      # @param describe [Boolean] whether this is a describe command
      # @param context [Hash] additional context passed to presenter
      # @return [String] formatted wide table string
      def format(data, presenter, color_enabled: true, describe: false, **context)
        # For describe (single resource), delegate to Table formatter
        # Wide format has no meaning for vertical key-value layout
        if describe || !collection?(data)
          Table.new.format(data, presenter, color_enabled: color_enabled, describe: true, **context)
        else
          format_wide_table(data, presenter, color_enabled, **context)
        end
      end

      private

      # Formats collection as wide table.
      #
      # @param data [Array] collection of models
      # @param presenter [Presenters::Base] presenter
      # @param color_enabled [Boolean] whether to apply color
      # @param context [Hash] context passed to presenter
      # @return [String] formatted wide table
      def format_wide_table(data, presenter, color_enabled, **context)
        pastel = ColorSupport.pastel(explicit_flag: color_enabled)
        headers = presenter.wide_columns
        rows = data.map do |model|
          row = presenter.to_wide_row(model, **context)
          colorize_row(row, headers, pastel)
        end

        render_table(headers, rows)
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
            value.nil? ? "-" : value
          end
        end
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
