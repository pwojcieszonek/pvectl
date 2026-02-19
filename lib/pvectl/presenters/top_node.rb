# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for node resource usage metrics (top command).
    #
    # Inherits from Presenters::Node for reuse of formatting methods.
    # Focuses on CPU, memory, disk, and swap utilization rather than
    # operational details (version, kernel, services).
    #
    # @example Using with formatter
    #   presenter = TopNode.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(nodes, presenter)
    #
    # @see Pvectl::Presenters::Node Parent presenter
    # @see Pvectl::Commands::Top::Command Top command
    #
    class TopNode < Node
      include TopPresenter

      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NAME CPU(cores) CPU% MEMORY MEMORY%]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[DISK DISK% SWAP SWAP% LOAD GUESTS]
      end

      # Converts Node model to table row with metrics values.
      #
      # @param model [Models::Node] Node model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @node = model
        cores = node.offline? ? "-" : cpu_cores_value(node)
        [
          node.name,
          cores,
          cpu_percent,
          memory_display,
          memory_percent_display(node)
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Node] Node model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @node = model
        [
          storage_display,
          percent_display(node.disk, node.maxdisk),
          swap_display,
          swap_percent_display(node),
          load_display,
          node.guests_total.to_s
        ]
      end

      # Converts Node model to hash for JSON/YAML output.
      #
      # Returns metrics-focused hash without operational info
      # (no version, kernel, uptime, alerts, network).
      #
      # @param model [Models::Node] Node model
      # @return [Hash] metrics-focused hash representation
      def to_hash(model)
        @node = model
        {
          "name" => node.name,
          "cpu" => {
            "usage_percent" => node.cpu.nil? ? nil : (node.cpu * 100).round,
            "cores" => node.maxcpu
          },
          "memory" => {
            "used_bytes" => node.mem,
            "total_bytes" => node.maxmem,
            "usage_percent" => memory_percent(node)
          },
          "disk" => {
            "used_bytes" => node.disk,
            "total_bytes" => node.maxdisk,
            "usage_percent" => storage_percent(node)
          },
          "swap" => {
            "used_bytes" => node.swap_used,
            "total_bytes" => node.swap_total,
            "usage_percent" => swap_percent(node)
          },
          "load" => {
            "avg1" => node.loadavg&.dig(0),
            "avg5" => node.loadavg&.dig(1),
            "avg15" => node.loadavg&.dig(2)
          },
          "guests" => {
            "total" => node.guests_total,
            "vms" => node.guests_vms,
            "cts" => node.guests_cts
          }
        }
      end

    end
  end
end
