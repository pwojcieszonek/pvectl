# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates non-interactive volume property updates.
    #
    # Handles two types of changes:
    # 1. Size changes — delegates to ResizeVolume service (irreversible)
    # 2. Config changes (cache, discard, ssd, etc.) — rebuilds volume config string
    #
    # @example Resize only
    #   service = SetVolume.new(repository: vm_repo, resource_type: :vm)
    #   result = service.execute(id: 100, disk: "scsi0", params: { "size" => "+10G" }, node: "pve1")
    #
    # @example Config change
    #   service.execute(id: 100, disk: "scsi0", params: { "cache" => "writeback" }, node: "pve1")
    #
    # @example Mixed (size + config)
    #   service.execute(id: 100, disk: "scsi0",
    #     params: { "size" => "+10G", "cache" => "writeback" }, node: "pve1")
    #
    class SetVolume
      # @param repository [Repositories::Vm, Repositories::Container] resource repository
      # @param resource_type [Symbol] :vm or :container
      def initialize(repository:, resource_type:)
        @repository = repository
        @resource_type = resource_type
      end

      # Executes the volume property update.
      #
      # Separates size param (delegated to ResizeVolume) from config params
      # (rebuilt into the disk config string). Both can be applied in a single call.
      #
      # @param id [Integer] resource ID (VMID or CTID)
      # @param disk [String] disk name (e.g., "scsi0", "rootfs")
      # @param params [Hash] key-value pairs to set
      # @param node [String] node name
      # @return [Models::VolumeOperationResult] operation result
      def execute(id:, disk:, params:, node:)
        config = @repository.fetch_config(node, id)
        disk_value = config[disk.to_sym]

        unless disk_value
          return build_result(id, disk, node, success: false,
                              error: "Volume '#{disk}' not found in config for resource #{id}")
        end

        # Separate size from config params (dup to avoid mutating caller's hash)
        params = params.dup
        size_param = params.delete("size") || params.delete(:size)
        config_params = params

        # Handle size change (resize)
        if size_param
          parsed_size = ResizeVolume.parse_size(size_param)
          resize_service = ResizeVolume.new(repository: @repository)
          resize_service.preflight(id, disk, parsed_size, node: node)
          resize_service.perform(id, disk, parsed_size.raw, node: node)
        end

        # Handle config changes (cache, discard, ssd, iothread, backup)
        unless config_params.empty?
          new_disk_value = rebuild_disk_config(disk_value, config_params)
          @repository.update(id, node, { disk.to_sym => new_disk_value })
        end

        build_result(id, disk, node, success: true)
      rescue ResizeVolume::VolumeNotFoundError, ResizeVolume::SizeTooSmallError, ArgumentError => e
        build_result(id, disk, node, success: false, error: e.message)
      rescue StandardError => e
        build_result(id, disk, node, success: false, error: e.message)
      end

      private

      # Rebuilds a disk config string with updated properties.
      #
      # Config format: "storage:volume-id,key1=val1,key2=val2"
      # Replaces existing keys and appends new ones.
      #
      # @param current_value [String] current disk config string
      # @param updates [Hash] key-value pairs to update
      # @return [String] updated config string
      def rebuild_disk_config(current_value, updates)
        parts = current_value.to_s.split(",")
        base = parts.shift # "storage:volume-id"

        # Parse existing key=value pairs
        existing = {}
        parts.each do |part|
          key, value = part.split("=", 2)
          existing[key] = value
        end

        # Apply updates
        updates.each do |key, value|
          existing[key.to_s] = value.to_s
        end

        # Rebuild string
        config_parts = existing.map { |k, v| "#{k}=#{v}" }
        ([base] + config_parts).join(",")
      end

      # Builds a VolumeOperationResult with volume metadata.
      #
      # @param id [Integer] resource ID
      # @param disk [String] disk name
      # @param node [String] node name
      # @param attrs [Hash] result attributes (:success, :error)
      # @return [Models::VolumeOperationResult]
      def build_result(id, disk, node, **attrs)
        volume = Models::Volume.new(
          name: disk,
          resource_type: @resource_type.to_s,
          resource_id: id,
          node: node
        )
        Models::VolumeOperationResult.new(
          operation: :set, volume: volume, **attrs
        )
      end
    end
  end
end
