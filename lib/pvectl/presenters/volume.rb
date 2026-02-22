# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for virtual disks (volumes) attached to VMs and containers.
    #
    # Defines column layout and formatting for table output.
    # Standard columns show node, resource type, ID, name, storage, size, and format.
    # Wide columns add volume ID, cache, discard, SSD, iothread, and backup flags.
    #
    # @example Using with formatter
    #   presenter = Volume.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(volumes, presenter)
    #
    # @see Pvectl::Models::Volume Volume model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Volume < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE RESOURCE ID NAME STORAGE SIZE FORMAT]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[VOLUME-ID CACHE DISCARD SSD IOTHREAD BACKUP]
      end

      # Converts Volume model to table row values.
      #
      # @param model [Models::Volume] Volume model
      # @param _context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @volume = model
        [
          volume.node || "-",
          volume.resource_type || "-",
          volume.resource_id&.to_s || "-",
          volume.name || "-",
          volume.storage || "-",
          volume.size || "-",
          volume.format || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Volume] Volume model
      # @param _context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @volume = model
        [
          volume.volume_id || "-",
          volume.cache || "-",
          volume.discard || "-",
          volume.ssd&.to_s || "-",
          volume.iothread&.to_s || "-",
          volume.backup&.to_s || "-"
        ]
      end

      # Converts Volume model to hash for JSON/YAML output.
      #
      # @param model [Models::Volume] Volume model
      # @return [Hash{String => untyped}] hash representation with string keys
      def to_hash(model)
        @volume = model
        {
          "name" => volume.name,
          "storage" => volume.storage,
          "volume_id" => volume.volume_id,
          "volid" => volume.volid,
          "size" => volume.size,
          "format" => volume.format,
          "resource_type" => volume.resource_type,
          "resource_id" => volume.resource_id,
          "node" => volume.node,
          "content" => volume.content,
          "cache" => volume.cache,
          "discard" => volume.discard,
          "ssd" => volume.ssd,
          "iothread" => volume.iothread,
          "backup" => volume.backup,
          "mp" => volume.mp
        }
      end

      # Returns detailed description for describe command output.
      #
      # @param model [Models::Volume] Volume model
      # @return [Hash{String => Hash{String, String}}] nested hash with Volume Info section
      def to_description(model)
        @volume = model
        { "Volume Info" => volume_info_section }
      end

      private

      # @return [Models::Volume] the current volume being presented
      attr_reader :volume

      # Builds the Volume Info section hash.
      # Optional fields are only included when they have values.
      #
      # @return [Hash{String => String}] volume info key-value pairs
      def volume_info_section
        info = {
          "Name" => volume.name || "-",
          "Storage" => volume.storage || "-",
          "Volume ID" => volume.volume_id || "-",
          "Full Volume ID" => volume.volid || "-",
          "Size" => volume.size || "-",
          "Format" => volume.format || "-",
          "Resource Type" => volume.resource_type || "-",
          "Resource ID" => volume.resource_id&.to_s || "-",
          "Node" => volume.node || "-"
        }
        info["Content"] = volume.content if volume.content
        info["Cache"] = volume.cache if volume.cache
        info["Discard"] = volume.discard if volume.discard
        info["SSD"] = volume.ssd if volume.ssd
        info["IO Thread"] = volume.iothread if volume.iothread
        info["Backup"] = volume.backup if volume.backup
        info["Mount Point"] = volume.mp if volume.mp
        info
      end
    end
  end
end
