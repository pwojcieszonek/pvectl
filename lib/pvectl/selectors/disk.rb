# frozen_string_literal: true

module Pvectl
  module Selectors
    # Selector for filtering physical disks.
    #
    # Extends Base with disk-specific field extraction.
    # Supports: type, health, used, node, gpt, mounted.
    #
    # @example Filter SSDs only
    #   selector = Disk.parse("type=ssd")
    #   ssds = selector.apply(all_disks)
    #
    # @example Filter healthy disks on a specific node
    #   selector = Disk.parse("health=PASSED,node=pve1")
    #   filtered = selector.apply(all_disks)
    #
    class Disk < Base
      SUPPORTED_FIELDS = %w[type health used node gpt mounted].freeze

      # Applies selector to disk collection.
      #
      # @param disks [Array<Models::PhysicalDisk>] disks to filter
      # @return [Array<Models::PhysicalDisk>] filtered disks
      def apply(disks)
        return disks if empty?

        disks.select { |disk| matches?(disk) }
      end

      protected

      # Extracts field value from PhysicalDisk model.
      #
      # @param disk [Models::PhysicalDisk] disk model
      # @param field [String] field name
      # @return [String, nil] field value
      # @raise [ArgumentError] if field is not supported
      def extract_value(disk, field)
        case field
        when "type"
          disk.type
        when "health"
          disk.health
        when "used"
          disk.used
        when "node"
          disk.node
        when "gpt"
          disk.gpt? ? "yes" : "no"
        when "mounted"
          disk.mounted? ? "yes" : "no"
        else
          raise ArgumentError, "Unknown field: #{field}. Supported: #{SUPPORTED_FIELDS.join(', ')}"
        end
      end
    end
  end
end
