# frozen_string_literal: true

module Pvectl
  module Selectors
    # Selector for filtering virtual disk volumes.
    #
    # Extends Base with volume-specific field extraction.
    # Supports: format, storage, node, content, resource_type, name.
    #
    # @example Filter raw volumes only
    #   selector = Volume.parse("format=raw")
    #   raw_vols = selector.apply(all_volumes)
    #
    # @example Filter volumes on a specific storage and node
    #   selector = Volume.parse("storage=local-lvm,node=pve1")
    #   filtered = selector.apply(all_volumes)
    #
    class Volume < Base
      SUPPORTED_FIELDS = %w[format storage node content resource_type name].freeze

      # Applies selector to volume collection.
      #
      # @param volumes [Array<Models::Volume>] volumes to filter
      # @return [Array<Models::Volume>] filtered volumes
      def apply(volumes)
        return volumes if empty?

        volumes.select { |vol| matches?(vol) }
      end

      protected

      # Extracts field value from Volume model.
      #
      # @param vol [Models::Volume] volume model
      # @param field [String] field name
      # @return [String, nil] field value
      # @raise [ArgumentError] if field is not supported
      def extract_value(vol, field)
        case field
        when "format"
          vol.format
        when "storage"
          vol.storage
        when "node"
          vol.node
        when "content"
          vol.content
        when "resource_type"
          vol.resource_type
        when "name"
          vol.name
        else
          raise ArgumentError, "Unknown field: #{field}. Supported: #{SUPPORTED_FIELDS.join(', ')}"
        end
      end
    end
  end
end
