# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for template listing (mixed VM and Container templates).
    #
    # Handles both Models::Vm and Models::Container via duck typing.
    # Both models share: vmid, name, type, node, maxdisk, tags.
    #
    # @example Using with formatter
    #   presenter = Template.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(templates, presenter)
    #
    # @see Pvectl::Models::Vm VM model
    # @see Pvectl::Models::Container Container model
    #
    class Template < Base
      # Returns column headers for template listing.
      #
      # @return [Array<String>] column names
      def columns
        %w[ID NAME TYPE NODE DISK TAGS]
      end

      # Converts a template model to table row.
      #
      # @param model [Models::Vm, Models::Container] template model
      # @param context [Hash] unused
      # @return [Array<String>] row values
      def to_row(model, **_context)
        [
          model.vmid.to_s,
          model.name || "-",
          model.type || "-",
          model.node || "-",
          format_disk(model.maxdisk),
          model.tags || "-"
        ]
      end

      # Converts a template model to hash for JSON/YAML.
      #
      # @param model [Models::Vm, Models::Container] template model
      # @return [Hash] hash representation
      def to_hash(model)
        {
          "id" => model.vmid,
          "name" => model.name,
          "type" => model.type,
          "node" => model.node,
          "disk" => model.maxdisk,
          "tags" => model.tags
        }
      end

      private

      # Formats disk size in human-readable format.
      #
      # @param bytes [Integer, nil] disk size in bytes
      # @return [String] formatted size
      def format_disk(bytes)
        return "-" unless bytes && bytes.positive?

        if bytes >= 1_073_741_824
          "#{(bytes.to_f / 1_073_741_824).round(1)}G"
        elsif bytes >= 1_048_576
          "#{(bytes.to_f / 1_048_576).round(1)}M"
        else
          "#{bytes}B"
        end
      end
    end
  end
end
