# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a VM/container backup in Proxmox.
    #
    # A backup is a full copy of a VM or container stored on a storage backend.
    # Backups can be created via vzdump and restored to create new VMs/containers.
    #
    # @example Creating a backup model
    #   backup = Backup.new(
    #     volid: "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst",
    #     vmid: 100,
    #     size: 1610612736,
    #     ctime: 1705315800,
    #     format: "vma"
    #   )
    #   backup.human_size   # => "1.5 GiB"
    #   backup.vm?          # => true
    #
    # @see Pvectl::Models::Base Base model class
    #
    class Backup < Base
      # @return [String] full volume identifier (e.g., "local:backup/vzdump-qemu-100-xxx.vma.zst")
      attr_reader :volid

      # @return [Integer] VM/container ID
      attr_reader :vmid

      # @return [String, nil] node name where backup is stored
      attr_reader :node

      # @return [String, nil] storage name (extracted from volid)
      attr_reader :storage

      # @return [Symbol, nil] resource type (:qemu or :lxc)
      attr_reader :resource_type

      # @return [String, nil] backup format ("vma", "tar")
      attr_reader :format

      # @return [Integer, nil] backup size in bytes
      attr_reader :size

      # @return [Integer, nil] Unix timestamp when backup was created
      attr_reader :ctime

      # @return [String, nil] optional notes/description
      attr_reader :notes

      # @return [Boolean] whether backup is protected from deletion
      attr_reader :protected

      # Creates a new Backup instance.
      #
      # @param attrs [Hash] backup attributes
      # @option attrs [String] :volid volume identifier
      # @option attrs [Integer] :vmid VM/container ID
      # @option attrs [String] :node node name
      # @option attrs [String] :storage storage name (auto-detected from volid if not provided)
      # @option attrs [Symbol] :resource_type :qemu or :lxc (auto-detected from volid if not provided)
      # @option attrs [String] :format backup format
      # @option attrs [Integer] :size size in bytes
      # @option attrs [Integer] :ctime Unix timestamp of creation
      # @option attrs [String] :notes description
      # @option attrs [Boolean] :protected protection status
      def initialize(attrs = {})
        super
        @volid = attributes[:volid]
        @vmid = attributes[:vmid]
        @node = attributes[:node]
        @storage = attributes[:storage] || extract_storage
        @resource_type = attributes[:resource_type] || detect_resource_type
        @format = attributes[:format]
        @size = attributes[:size]
        @ctime = attributes[:ctime]
        @notes = attributes[:notes]
        @protected = attributes[:protected] || false
      end

      # Returns the backup creation time as a Time object.
      #
      # @return [Time, nil] creation time or nil if ctime is not set
      def created_at
        return nil if ctime.nil?

        Time.at(ctime)
      end

      # Checks if the backup is for a VM (QEMU).
      #
      # @return [Boolean] true if resource_type is :qemu
      def vm?
        resource_type == :qemu
      end

      # Checks if the backup is for a container (LXC).
      #
      # @return [Boolean] true if resource_type is :lxc
      def container?
        resource_type == :lxc
      end

      # Extracts the filename from the volume identifier.
      #
      # @return [String, nil] filename or nil if volid is not set
      def filename
        return nil if volid.nil?

        volid.split("/").last
      end

      # Returns human-readable size.
      #
      # @return [String, nil] formatted size (e.g., "1.5 GiB") or nil if size is not set
      def human_size
        return nil if size.nil?

        format_bytes(size)
      end

      # Checks if the backup is protected from deletion.
      #
      # @return [Boolean] true if protected
      def protected?
        @protected == true
      end

      private

      # Extracts storage name from volid.
      #
      # @return [String, nil] storage name
      def extract_storage
        return nil if volid.nil?

        volid.split(":").first
      end

      # Detects resource type from volid pattern.
      #
      # @return [Symbol, nil] :qemu, :lxc, or nil
      def detect_resource_type
        return nil if volid.nil?
        return :qemu if volid.include?("vzdump-qemu")
        return :lxc if volid.include?("vzdump-lxc")

        nil
      end

      # Formats bytes into human-readable units.
      #
      # @param bytes [Integer] size in bytes
      # @return [String] formatted size
      def format_bytes(bytes)
        units = ["B", "KiB", "MiB", "GiB", "TiB"]
        unit_index = 0
        value = bytes.to_f

        while value >= 1024 && unit_index < units.size - 1
          value /= 1024
          unit_index += 1
        end

        if unit_index == 0
          "#{value.to_i} #{units[unit_index]}"
        else
          "#{Kernel.format('%.1f', value)} #{units[unit_index]}"
        end
      end
    end
  end
end
