# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for container resource usage metrics (top command).
    #
    # Inherits from Presenters::Container for reuse of formatting methods.
    # Includes TopPresenter for shared metrics display.
    # Focuses on CPU, memory, swap, disk, and network utilization.
    #
    # @example Using with formatter
    #   presenter = TopContainer.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(containers, presenter)
    #
    # @see Pvectl::Presenters::Container Parent presenter
    # @see Pvectl::Presenters::TopPresenter Shared metrics module
    # @see Pvectl::Commands::Top::Command Top command
    #
    class TopContainer < Container
      include TopPresenter

      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[CTID NAME NODE CPU(cores) CPU% MEMORY MEMORY%]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[SWAP SWAP% DISK DISK% NETIN NETOUT]
      end

      # Converts Container model to table row with metrics values.
      #
      # @param model [Models::Container] Container model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @container = model
        [
          container.vmid.to_s,
          display_name,
          container.node,
          cpu_cores_value(container),
          cpu_usage_value(container),
          memory_display,
          percent_display(container.mem, container.maxmem)
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Container] Container model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @container = model
        [
          swap_display,
          percent_display(container.swap, container.maxswap),
          disk_display,
          percent_display(container.disk, container.maxdisk),
          netin_display,
          netout_display
        ]
      end

      # Converts Container model to hash for JSON/YAML output.
      #
      # Returns metrics-focused hash without operational info
      # (no status, template, tags, pool, uptime).
      #
      # @param model [Models::Container] Container model
      # @return [Hash] metrics-focused hash representation
      def to_hash(model)
        @container = model
        {
          "ctid" => container.vmid,
          "name" => container.name,
          "node" => container.node,
          "cpu" => {
            "usage_percent" => container.cpu.nil? ? nil : (container.cpu * 100).round,
            "cores" => container.maxcpu
          },
          "memory" => {
            "used_bytes" => container.mem,
            "total_bytes" => container.maxmem,
            "usage_percent" => percent_value(container.mem, container.maxmem)
          },
          "swap" => {
            "used_bytes" => container.swap,
            "total_bytes" => container.maxswap,
            "usage_percent" => percent_value(container.swap, container.maxswap)
          },
          "disk" => {
            "used_bytes" => container.disk,
            "total_bytes" => container.maxdisk,
            "usage_percent" => percent_value(container.disk, container.maxdisk)
          },
          "network" => {
            "in_bytes" => container.netin,
            "out_bytes" => container.netout
          }
        }
      end
    end
  end
end
