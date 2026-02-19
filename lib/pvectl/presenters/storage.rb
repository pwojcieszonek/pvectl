# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for Proxmox cluster storage pools.
    #
    # Defines column layout and formatting for table output.
    # Standard columns show essential storage info.
    # Wide columns add content types and shared status.
    #
    # @example Using with formatter
    #   presenter = Storage.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(storage_pools, presenter)
    #
    # @see Pvectl::Models::Storage Storage model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Storage < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NAME TYPE STATUS USED TOTAL %USED NODE]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[CONTENT SHARED]
      end

      # Converts Storage model to table row values.
      #
      # @param model [Models::Storage] Storage model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        @storage = model
        [
          storage.name,
          type_display,
          status_display,
          used_display,
          total_display,
          usage_display,
          node_display
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Storage] Storage model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        @storage = model
        [
          content_display,
          shared_display
        ]
      end

      # Converts Storage model to hash for JSON/YAML output.
      #
      # Returns a structured hash with nested objects for complex data.
      #
      # @param model [Models::Storage] Storage model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        @storage = model
        {
          "name" => storage.name,
          "type" => storage.plugintype,
          "status" => storage.status,
          "node" => storage.node,
          "shared" => storage.shared?,
          "content" => storage.content,
          "disk" => {
            "used_bytes" => storage.disk,
            "total_bytes" => storage.maxdisk,
            "used_gb" => disk_used_gb,
            "total_gb" => disk_total_gb,
            "usage_percent" => usage_percent
          }
        }
      end

      # Converts Storage model to description format for describe command.
      #
      # Returns a structured Hash with sections for kubectl-style vertical output.
      # Nested Hashes create indented subsections.
      # Arrays of Hashes render as inline tables.
      #
      # @param model [Models::Storage] Storage model with describe details
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        @storage = model

        {
          "Name" => storage.name,
          "Type" => type_display,
          "Status" => status_display,
          "Shared" => shared_display,
          "Nodes" => nodes_display,

          "Capacity" => build_capacity_section,

          "Configuration" => build_configuration_section,

          "Content Summary" => format_content_summary,

          "Backup Retention" => format_backup_retention
        }
      end

      # -----------------------------------------------------------------
      # Display Methods (moved from Models::Storage)
      # -----------------------------------------------------------------

      # Returns storage type for display.
      #
      # @return [String] storage plugin type or "-"
      def type_display
        storage.plugintype || "-"
      end

      # Returns status for display.
      # Maps "available" to "active" for consistency with kubectl style.
      #
      # @return [String] status (active, inactive)
      def status_display
        storage.active? ? "active" : "inactive"
      end

      # Returns node display.
      # Shows "-" for shared storage (available on multiple nodes).
      #
      # @return [String] node name or "-" for shared storage
      def node_display
        storage.shared? ? "-" : (storage.node || "-")
      end

      # Returns disk used in GB.
      #
      # @return [Float, nil] disk used in GB, or nil if unavailable
      def disk_used_gb
        return nil if storage.disk.nil?

        (storage.disk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns total disk in GB.
      #
      # @return [Float, nil] total disk in GB, or nil if unavailable
      def disk_total_gb
        return nil if storage.maxdisk.nil?

        (storage.maxdisk.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns storage usage percentage.
      #
      # @return [Integer, nil] usage percentage (0-100), or nil if unavailable
      def usage_percent
        return nil if storage.maxdisk.nil? || storage.maxdisk.zero? || storage.disk.nil?

        ((storage.disk.to_f / storage.maxdisk) * 100).round
      end

      # Returns available bytes in GB.
      #
      # @return [Float, nil] available bytes in GB, or nil if unavailable
      def avail_gb
        return nil if storage.avail.nil?

        (storage.avail.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Returns available storage formatted with appropriate unit (GB or TB).
      #
      # @return [String] formatted available storage (e.g., "55 GB" or "2.0 TB") or "-"
      def avail_display
        return "-" unless storage.active? && avail_gb

        format_size(avail_gb)
      end

      # Returns used storage formatted with appropriate unit (GB or TB).
      #
      # @return [String] formatted used storage (e.g., "45 GB" or "1.2 TB") or "-"
      def used_display
        return "-" unless storage.active? && disk_used_gb

        format_size(disk_used_gb)
      end

      # Returns total storage formatted with appropriate unit (GB or TB).
      #
      # @return [String] formatted total storage (e.g., "100 GB" or "2.0 TB") or "-"
      def total_display
        return "-" if disk_total_gb.nil?

        format_size(disk_total_gb)
      end

      # Returns usage percentage for display.
      #
      # @return [String] percentage (e.g., "45%") or "-" if unavailable
      def usage_display
        return "-" unless storage.active? && usage_percent

        "#{usage_percent}%"
      end

      # Returns content types for display.
      #
      # @return [String] comma-separated content types or "-"
      def content_display
        storage.content.nil? || storage.content.empty? ? "-" : storage.content
      end

      # Returns shared status for display.
      #
      # @return [String] "yes" or "no"
      def shared_display
        storage.shared? ? "yes" : "no"
      end

      private

      # @return [Models::Storage] the current storage being presented
      attr_reader :storage

      # Formats size with appropriate unit (GB or TB).
      #
      # @param gb [Float] size in GB
      # @return [String] formatted size
      def format_size(gb)
        if gb >= 1024
          "#{(gb / 1024).round(1)} TB"
        else
          "#{gb.round(0).to_i} GB"
        end
      end

      # -----------------------------------------------------------------
      # Helper methods for to_description
      # -----------------------------------------------------------------

      # Returns nodes display for describe output.
      # Shows "all" if nodes_allowed is nil (available on all nodes).
      #
      # @return [String] nodes list or "all"
      def nodes_display
        storage.nodes_allowed.nil? ? "all" : storage.nodes_allowed
      end

      # Builds the capacity section for describe output.
      #
      # @return [Hash] capacity metrics
      def build_capacity_section
        {
          "Total" => total_display,
          "Used" => used_display,
          "Available" => avail_display,
          "Usage" => usage_display
        }
      end

      # Builds the configuration section for describe output.
      # Includes type-specific configuration fields.
      #
      # @return [Hash, String] configuration fields or "-" if empty
      def build_configuration_section
        config = {}
        config["Path"] = storage.path if storage.path
        config["Server"] = storage.server if storage.server
        config["Export"] = storage.export if storage.export
        config["Volume Group"] = storage.vgname if storage.vgname
        config["Thin Pool"] = storage.thinpool if storage.thinpool
        config["Pool"] = storage.pool if storage.pool
        config["Content Types"] = storage.content if storage.content
        config.empty? ? "-" : config
      end

      # Formats content summary from volumes list.
      # Groups volumes by type and calculates counts and sizes.
      #
      # @return [Array<Hash>, String] formatted table data or "-" if no volumes
      def format_content_summary
        return "-" if storage.volumes.nil? || storage.volumes.empty?

        # Group volumes by content type
        grouped = storage.volumes.group_by { |v| v[:content] || v["content"] }

        grouped.map do |content_type, volumes|
          total_size = volumes.sum { |v| v[:size] || v["size"] || 0 }
          size_gb = (total_size.to_f / 1024 / 1024 / 1024).round(1)
          {
            "TYPE" => content_type || "-",
            "COUNT" => volumes.size.to_s,
            "SIZE" => format_size(size_gb)
          }
        end
      end

      # Formats backup retention policy for describe output.
      #
      # @return [Hash, String] retention settings or "-" if not configured
      def format_backup_retention
        return "-" if storage.prune_backups.nil?

        retention = {}
        prune = storage.prune_backups

        # Handle both string and symbol keys
        retention["Keep Last"] = prune[:"keep-last"] || prune["keep-last"] if prune[:"keep-last"] || prune["keep-last"]
        retention["Keep Daily"] = prune[:"keep-daily"] || prune["keep-daily"] if prune[:"keep-daily"] || prune["keep-daily"]
        retention["Keep Weekly"] = prune[:"keep-weekly"] || prune["keep-weekly"] if prune[:"keep-weekly"] || prune["keep-weekly"]
        retention["Keep Monthly"] = prune[:"keep-monthly"] || prune["keep-monthly"] if prune[:"keep-monthly"] || prune["keep-monthly"]
        retention["Keep Yearly"] = prune[:"keep-yearly"] || prune["keep-yearly"] if prune[:"keep-yearly"] || prune["keep-yearly"]

        retention.empty? ? "-" : retention
      end
    end
  end
end
