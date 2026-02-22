# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates the interactive volume property editing flow.
    #
    # Fetches the disk config string from VM/CT config, parses it into
    # editable YAML (key-value pairs), opens editor, and applies changes.
    # Size changes delegate to ResizeVolume; config changes rebuild the
    # disk config string.
    #
    # @example Basic usage
    #   service = EditVolume.new(repository: vm_repo, resource_type: :vm)
    #   result = service.execute(id: 100, disk: "scsi0", node: "pve1")
    #
    # @example Dry run with injected editor session
    #   service = EditVolume.new(repository: vm_repo, resource_type: :vm,
    #                            editor_session: session, options: { dry_run: true })
    #   result = service.execute(id: 100, disk: "scsi0", node: "pve1")
    #
    class EditVolume
      # @param repository [Repositories::Vm, Repositories::Container] resource repository
      # @param resource_type [Symbol] :vm or :container
      # @param editor_session [EditorSession, nil] optional injected editor session
      # @param options [Hash] options (dry_run)
      def initialize(repository:, resource_type:, editor_session: nil, options: {})
        @repository = repository
        @resource_type = resource_type
        @editor_session = editor_session
        @options = options
      end

      # Executes the interactive volume edit flow.
      #
      # @param id [Integer] resource ID (VMID or CTID)
      # @param disk [String] disk name (e.g., "scsi0", "rootfs")
      # @param node [String] node name
      # @return [Models::VolumeOperationResult, nil] result, or nil if cancelled/no changes
      def execute(id:, disk:, node:)
        config = @repository.fetch_config(node, id)
        disk_value = config[disk.to_sym]

        unless disk_value
          return build_result(id, disk, node, success: false,
                              error: "Volume '#{disk}' not found in config for resource #{id}")
        end

        editable = parse_disk_config(disk_value)
        yaml_content = build_yaml_content(editable, disk, id, node)

        session = @editor_session || EditorSession.new
        edited = session.edit(yaml_content)

        return nil unless edited

        edited_config = parse_edited_yaml(edited)
        changes = compute_diff(editable, edited_config)

        return nil if no_changes?(changes)

        if @options[:dry_run]
          return build_result(id, disk, node, success: true,
                              resource: { diff: changes })
        end

        apply_changes(id, disk, node, disk_value, changes)
        build_result(id, disk, node, success: true)
      rescue ResizeVolume::VolumeNotFoundError, ResizeVolume::SizeTooSmallError, ArgumentError => e
        build_result(id, disk, node, success: false, error: e.message)
      rescue StandardError => e
        build_result(id, disk, node, success: false, error: e.message)
      end

      private

      # Parses a disk config string into a hash of editable properties.
      #
      # Input: "local-lvm:vm-100-disk-0,size=32G,cache=none"
      # Output: { "size" => "32G", "cache" => "none" }
      #
      # The base (storage:vol-id) is NOT included — it's read-only.
      #
      # @param disk_value [String] disk config string
      # @return [Hash] editable properties with string keys
      def parse_disk_config(disk_value)
        parts = disk_value.to_s.split(",")
        parts.shift # Remove base "storage:vol-id"

        props = {}
        parts.each do |part|
          key, value = part.split("=", 2)
          props[key] = value
        end
        props
      end

      # Builds YAML content for the editor with comment header.
      #
      # @param editable [Hash] editable properties
      # @param disk [String] disk name
      # @param id [Integer] resource ID
      # @param node [String] node name
      # @return [String] YAML content with comments
      def build_yaml_content(editable, disk, id, node)
        "# Volume: #{disk} (resource #{id} on #{node})\n" \
          "# Edit properties below. Save and close to apply.\n" +
          editable.to_yaml
      end

      # Parses edited YAML content, stripping comment lines.
      #
      # @param edited [String] raw editor content
      # @return [Hash] parsed config with string keys
      def parse_edited_yaml(edited)
        cleaned = edited.lines.reject { |l| l.strip.start_with?("#") }.join
        YAML.safe_load(cleaned) || {}
      end

      # Checks whether the diff contains any actual changes.
      #
      # @param changes [Hash] diff hash with :changed, :added, :removed
      # @return [Boolean] true if no changes detected
      def no_changes?(changes)
        changes[:changed].empty? && changes[:added].empty? && changes[:removed].empty?
      end

      # Computes diff between original and edited config.
      #
      # @param original [Hash] original config (string keys)
      # @param edited [Hash] edited config (string keys)
      # @return [Hash] diff with :changed, :added, :removed
      def compute_diff(original, edited)
        changed = {}
        added = {}
        removed = []

        edited.each do |key, value|
          orig_value = original[key.to_s]
          if orig_value.nil?
            added[key.to_s] = value
          elsif orig_value.to_s != value.to_s
            changed[key.to_s] = [orig_value.to_s, value.to_s]
          end
        end

        original.each_key do |key|
          removed << key.to_s unless edited.key?(key.to_s)
        end

        { changed: changed, added: added, removed: removed }
      end

      # Applies changes — delegates size to ResizeVolume, config to rebuild.
      #
      # @param id [Integer] resource ID
      # @param disk [String] disk name
      # @param node [String] node name
      # @param original_disk_value [String] original disk config string
      # @param changes [Hash] diff hash
      def apply_changes(id, disk, node, original_disk_value, changes)
        size_change = changes[:changed].delete("size") || changes[:added].delete("size")

        if size_change
          new_size = size_change.is_a?(Array) ? size_change[1] : size_change
          parsed_size = ResizeVolume.parse_size(new_size.to_s)
          resize_service = ResizeVolume.new(repository: @repository)
          resize_service.preflight(id, disk, parsed_size, node: node)
          resize_service.perform(id, disk, parsed_size.raw, node: node)
        end

        config_updates = {}
        changes[:changed].each { |key, (_old, new_val)| config_updates[key] = new_val }
        changes[:added].each { |key, val| config_updates[key] = val }

        if !config_updates.empty? || !changes[:removed].empty?
          new_disk_value = rebuild_disk_config(original_disk_value, config_updates, changes[:removed])
          @repository.update(id, node, { disk.to_sym => new_disk_value })
        end
      end

      # Rebuilds a disk config string with updated/removed properties.
      #
      # @param current_value [String] current disk config string
      # @param updates [Hash] key-value pairs to update
      # @param removed_keys [Array<String>] keys to remove
      # @return [String] updated config string
      def rebuild_disk_config(current_value, updates, removed_keys = [])
        parts = current_value.to_s.split(",")
        base = parts.shift

        existing = {}
        parts.each do |part|
          key, value = part.split("=", 2)
          existing[key] = value
        end

        updates.each { |key, value| existing[key.to_s] = value.to_s }
        removed_keys.each { |key| existing.delete(key.to_s) }

        config_parts = existing.map { |k, v| "#{k}=#{v}" }
        ([base] + config_parts).join(",")
      end

      # Builds a VolumeOperationResult.
      #
      # @param id [Integer] resource ID
      # @param disk [String] disk name
      # @param node [String] node name
      # @param attrs [Hash] additional result attributes
      # @return [Models::VolumeOperationResult]
      def build_result(id, disk, node, **attrs)
        volume = Models::Volume.new(
          name: disk,
          resource_type: @resource_type.to_s,
          resource_id: id,
          node: node
        )
        Models::VolumeOperationResult.new(
          operation: :edit, volume: volume, **attrs
        )
      end
    end
  end
end
