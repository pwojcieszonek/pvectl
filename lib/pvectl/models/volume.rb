# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a virtual disk (volume) attached to a VM or container.
    #
    # Volumes can originate from two data sources:
    # - VM/CT config (has name like "scsi0", parsed from config values)
    # - Storage content API (has volid, content type)
    #
    # @example From VM config
    #   Volume.new(name: "scsi0", storage: "local-lvm", volume_id: "vm-100-disk-0",
    #              size: "32G", resource_type: "vm", resource_id: 100, node: "pve1")
    #
    # @example From storage content API
    #   Volume.new(volid: "local-lvm:vm-100-disk-0", size: "32G", format: "raw",
    #              content: "images", resource_type: "vm", resource_id: 100, node: "pve1")
    #
    class Volume < Base
      # @return [String, nil] disk name from config (e.g., "scsi0", "rootfs")
      attr_reader :name

      # @return [String, nil] storage name (e.g., "local-lvm")
      attr_reader :storage

      # @return [String, nil] volume identifier within storage (e.g., "vm-100-disk-0")
      attr_reader :volume_id

      # @return [String, nil] full volume identifier (e.g., "local-lvm:vm-100-disk-0")
      attr_reader :volid

      # @return [String, nil] volume size (e.g., "32G")
      attr_reader :size

      # @return [String, nil] disk format (e.g., "raw", "qcow2")
      attr_reader :format

      # @return [String, nil] resource type ("vm" or "ct")
      attr_reader :resource_type

      # @return [Integer, nil] VMID or CTID
      attr_reader :resource_id

      # @return [String, nil] Proxmox node name
      attr_reader :node

      # @return [String, nil] storage content type (e.g., "images", "rootdir")
      attr_reader :content

      # @return [String, nil] cache mode (e.g., "writeback", "none")
      attr_reader :cache

      # @return [String, nil] discard mode (e.g., "on", "ignore")
      attr_reader :discard

      # @return [Integer, nil] SSD emulation flag (1/0)
      attr_reader :ssd

      # @return [Integer, nil] IO thread flag (1/0)
      attr_reader :iothread

      # @return [Integer, nil] backup inclusion flag (1/0)
      attr_reader :backup

      # @return [String, nil] mount point path (containers only)
      attr_reader :mp

      # Creates a new Volume instance.
      #
      # @param attrs [Hash] volume attributes
      # @option attrs [String] :name disk name from config
      # @option attrs [String] :storage storage name
      # @option attrs [String] :volume_id volume identifier within storage
      # @option attrs [String] :volid full volume identifier
      # @option attrs [String] :size volume size
      # @option attrs [String] :format disk format
      # @option attrs [String] :resource_type resource type ("vm" or "ct")
      # @option attrs [Integer] :resource_id VMID or CTID
      # @option attrs [String] :node Proxmox node name
      # @option attrs [String] :content storage content type
      # @option attrs [String] :cache cache mode
      # @option attrs [String] :discard discard mode
      # @option attrs [Integer] :ssd SSD emulation flag (1/0)
      # @option attrs [Integer] :iothread IO thread flag (1/0)
      # @option attrs [Integer] :backup backup inclusion flag (1/0)
      # @option attrs [String] :mp mount point path
      def initialize(attrs = {})
        super
        @name = attributes[:name]
        @storage = attributes[:storage]
        @volume_id = attributes[:volume_id]
        @volid = attributes[:volid] || construct_volid
        @size = attributes[:size]
        @format = attributes[:format]
        @resource_type = attributes[:resource_type]
        @resource_id = attributes[:resource_id]
        @node = attributes[:node]
        @content = attributes[:content]
        @cache = attributes[:cache]
        @discard = attributes[:discard]
        @ssd = attributes[:ssd]
        @iothread = attributes[:iothread]
        @backup = attributes[:backup]
        @mp = attributes[:mp]
      end

      # Checks if volume belongs to a VM.
      #
      # @return [Boolean]
      def vm?
        resource_type == "vm"
      end

      # Checks if volume belongs to a container.
      #
      # @return [Boolean]
      def container?
        resource_type == "ct"
      end

      private

      # Constructs volid from storage and volume_id when not provided directly.
      #
      # @return [String, nil]
      def construct_volid
        return nil unless storage && volume_id

        "#{storage}:#{volume_id}"
      end
    end
  end
end
