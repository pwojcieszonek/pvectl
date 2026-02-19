# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for VM resource usage metrics (top command).
    #
    # Inherits from Presenters::Vm for reuse of formatting methods.
    # Includes TopPresenter for shared metrics display.
    # Focuses on CPU, memory, disk, and network utilization.
    #
    # @example Using with formatter
    #   presenter = TopVm.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(vms, presenter)
    #
    # @see Pvectl::Presenters::Vm Parent presenter
    # @see Pvectl::Presenters::TopPresenter Shared metrics module
    # @see Pvectl::Commands::Top::Command Top command
    #
    class TopVm < Vm
      include TopPresenter

      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME NODE CPU(cores) CPU% MEMORY MEMORY%]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[DISK DISK% NETIN NETOUT]
      end

      # Converts VM model to table row with metrics values.
      #
      # @param model [Models::Vm] VM model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @vm = model
        [
          vm.vmid.to_s,
          display_name,
          vm.node,
          cpu_cores_value(vm),
          cpu_usage_value(vm),
          memory_display,
          percent_display(vm.mem, vm.maxmem)
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Vm] VM model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @vm = model
        [
          disk_display,
          percent_display(vm.disk, vm.maxdisk),
          format_bytes(vm.netin),
          format_bytes(vm.netout)
        ]
      end

      # Converts VM model to hash for JSON/YAML output.
      #
      # Returns metrics-focused hash without operational info
      # (no status, template, tags, ha, uptime).
      #
      # @param model [Models::Vm] VM model
      # @return [Hash] metrics-focused hash representation
      def to_hash(model)
        @vm = model
        {
          "vmid" => vm.vmid,
          "name" => vm.name,
          "node" => vm.node,
          "cpu" => {
            "usage_percent" => vm.cpu.nil? ? nil : (vm.cpu * 100).round,
            "cores" => vm.maxcpu
          },
          "memory" => {
            "used_bytes" => vm.mem,
            "total_bytes" => vm.maxmem,
            "usage_percent" => percent_value(vm.mem, vm.maxmem)
          },
          "disk" => {
            "used_bytes" => vm.disk,
            "total_bytes" => vm.maxdisk,
            "usage_percent" => percent_value(vm.disk, vm.maxdisk)
          },
          "network" => {
            "in_bytes" => vm.netin,
            "out_bytes" => vm.netout
          }
        }
      end
    end
  end
end
