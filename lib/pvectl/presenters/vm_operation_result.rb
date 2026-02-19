# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for VM lifecycle operation results.
    #
    # Formats VmOperationResult models for table/JSON/YAML output.
    #
    # @example Using with formatter
    #   presenter = VmOperationResult.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(results, presenter)
    #
    class VmOperationResult < OperationResult
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[VMID NAME NODE STATUS MESSAGE]
      end

      # Returns additional columns for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[TASK DURATION]
      end

      # Converts result to table row values.
      #
      # @param model [Models::VmOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] row values
      def to_row(model, **_context)
        [
          model.vm.vmid.to_s,
          display_name(model.vm),
          model.vm.node,
          status_display(model),
          model.message
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::VmOperationResult] result model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values
      def extra_values(model, **_context)
        [
          task_upid(model),
          duration_display(model)
        ]
      end

      # Converts result to hash for JSON/YAML output.
      #
      # @param model [Models::VmOperationResult] result model
      # @return [Hash] hash representation
      def to_hash(model)
        {
          "vmid" => model.vm.vmid,
          "name" => model.vm.name,
          "node" => model.vm.node,
          "status" => model.status_text,
          "message" => model.message,
          "task_upid" => model.task_upid || model.task&.upid
        }
      end

      private

      # Returns display name for VM.
      #
      # @param vm [Models::Vm] VM model
      # @return [String] display name
      def display_name(vm)
        vm.name || "VM-#{vm.vmid}"
      end
    end
  end
end
