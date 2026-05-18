# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for node capabilities (QEMU CPU models, machine types).
    #
    # Each Capability becomes one row regardless of kind. The DETAILS
    # column adapts to the kind: CPU rows show vendor (and the "custom"
    # marker when applicable), machine rows show the underlying machine
    # family (q35/i440fx).
    #
    # @example Using with formatter
    #   presenter = Capability.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(capabilities, presenter)
    #
    # @see Pvectl::Models::Capability
    #
    class Capability < Base
      # Returns column headers for table output.
      #
      # @return [Array<String>] column headers
      def columns
        ["NODE", "KIND", "NAME", "DETAILS"]
      end

      # Returns extra columns for wide output (machine version, custom flag).
      #
      # @return [Array<String>] extra columns
      def extra_columns
        ["VERSION"]
      end

      # Converts capability to a row.
      #
      # @param model [Models::Capability]
      # @param _context [Hash] unused
      # @return [Array<String>]
      def to_row(model, **_context)
        [
          model.node_name || "-",
          model.kind.to_s,
          model.name || "-",
          details(model)
        ]
      end

      # Returns extra values for wide output.
      #
      # @param model [Models::Capability]
      # @param _context [Hash] unused
      # @return [Array<String>]
      def extra_values(model, **_context)
        [model.version || "-"]
      end

      # Converts capability to a hash for JSON/YAML output.
      #
      # Only the fields relevant to the kind are included; unset fields
      # are omitted to keep the output compact and readable.
      #
      # @param model [Models::Capability]
      # @return [Hash{String => Object}]
      def to_hash(model)
        base = {
          "node" => model.node_name,
          "kind" => model.kind&.to_s,
          "name" => model.name
        }

        case model.kind
        when :cpu
          base["vendor"] = model.vendor if model.vendor
          base["custom"] = model.custom
        when :machine
          base["machine_type"] = model.machine_type if model.machine_type
          base["version"] = model.version if model.version
          base["changes"] = model.changes if model.changes
        end

        base
      end

      private

      # Returns the DETAILS column string.
      #
      # @param model [Models::Capability]
      # @return [String]
      def details(model)
        case model.kind
        when :cpu
          parts = [model.vendor].compact
          parts << "custom" if model.custom
          parts.empty? ? "-" : parts.join(" ")
        when :machine
          model.machine_type || "-"
        else
          "-"
        end
      end
    end
  end
end
