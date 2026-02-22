# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a physical disk (block device) on a Proxmox node.
    #
    # PhysicalDisk instances are created from the Proxmox API responses
    # and provide domain methods for disk analysis.
    #
    # @example Creating a disk from API data
    #   disk = PhysicalDisk.new(
    #     devpath: "/dev/sda",
    #     model: "Samsung SSD 970",
    #     size: 500_000_000_000,
    #     type: "ssd",
    #     health: "PASSED",
    #     node: "pve1",
    #     gpt: 1,
    #     mounted: 1,
    #     used: "LVM"
    #   )
    #   disk.ssd?      # => true
    #   disk.healthy?  # => true
    #   disk.size_gb   # => 465.7
    #   disk.gpt?      # => true
    #   disk.mounted?  # => true
    #   disk.osd?      # => false
    #
    # @see Pvectl::Models::Base Base class for all models
    #
    class PhysicalDisk < Base
      # @return [String, nil] device path (e.g., "/dev/sda")
      attr_reader :devpath

      # @return [String, nil] disk model name
      attr_reader :model

      # @return [Integer, nil] disk size in bytes
      attr_reader :size

      # @return [String, nil] disk type ("ssd", "hdd", etc.)
      attr_reader :type

      # @return [String, nil] SMART health status (e.g., "PASSED", "FAILED")
      attr_reader :health

      # @return [String, nil] disk serial number
      attr_reader :serial

      # @return [String, nil] disk vendor
      attr_reader :vendor

      # @return [String, nil] Proxmox node name this disk belongs to
      attr_reader :node

      # @return [Integer, nil] whether disk has a GPT partition table (1 = yes, 0 = no)
      attr_reader :gpt

      # @return [Integer, nil] whether disk is mounted (1 = yes, 0 = no)
      attr_reader :mounted

      # @return [String, nil] how the disk is used (e.g., "LVM", "ZFS", "ext4")
      attr_reader :used

      # @return [String, nil] World Wide Name identifier
      attr_reader :wwn

      # @return [Integer, nil] Ceph OSD ID (-1 if not an OSD)
      attr_reader :osdid

      # @return [String, nil] parent device path (e.g., "/dev/sda" for partition "/dev/sda1")
      attr_reader :parent

      # @return [String, nil] SMART type ("ata" or "text")
      attr_reader :smart_type

      # @return [Array<Hash>, nil] ATA SMART attributes array
      attr_reader :smart_attributes

      # @return [String, nil] raw SMART text (NVMe/SAS)
      attr_reader :smart_text

      # @return [Integer, nil] disk wearout percentage
      attr_reader :wearout

      # Creates a new PhysicalDisk instance.
      #
      # @param attrs [Hash] disk attributes from API
      # @option attrs [String] :devpath device path
      # @option attrs [String] :model disk model name
      # @option attrs [Integer] :size disk size in bytes
      # @option attrs [String] :type disk type
      # @option attrs [String] :health SMART health status
      # @option attrs [String] :serial serial number
      # @option attrs [String] :vendor vendor name
      # @option attrs [String] :node Proxmox node name
      # @option attrs [Integer] :gpt GPT partition table flag (1/0)
      # @option attrs [Integer] :mounted mounted flag (1/0)
      # @option attrs [String] :used usage type
      # @option attrs [String] :wwn World Wide Name
      # @option attrs [Integer] :osdid Ceph OSD ID
      # @option attrs [String] :parent parent device path
      # @option attrs [String] :smart_type SMART data type ("ata" or "text")
      # @option attrs [Array<Hash>] :smart_attributes ATA SMART attributes
      # @option attrs [String] :smart_text raw SMART text (NVMe/SAS)
      # @option attrs [Integer] :wearout wearout percentage
      def initialize(attrs = {})
        super
        @devpath = attributes[:devpath]
        @model = attributes[:model]
        @size = attributes[:size]
        @type = attributes[:type]
        @health = attributes[:health]
        @serial = attributes[:serial]
        @vendor = attributes[:vendor]
        @node = attributes[:node]
        @gpt = attributes[:gpt]
        @mounted = attributes[:mounted]
        @used = attributes[:used]
        @wwn = attributes[:wwn]
        @osdid = attributes[:osdid]
        @parent = attributes[:parent]
        @smart_type = attributes[:smart_type]
        @smart_attributes = attributes[:smart_attributes]
        @smart_text = attributes[:smart_text]
        @wearout = attributes[:wearout]
      end

      # Returns disk size in gigabytes.
      #
      # @return [Float, nil] size in GB (binary, 1024-based), or nil if size unknown
      #
      # @example
      #   disk = PhysicalDisk.new(size: 500_000_000_000)
      #   disk.size_gb # => 465.7
      def size_gb
        return nil if size.nil?

        (size.to_f / 1024 / 1024 / 1024).round(1)
      end

      # Checks if disk SMART health status is PASSED.
      #
      # @return [Boolean] true if health is "PASSED"
      def healthy?
        health == "PASSED"
      end

      # Checks if disk is an SSD.
      #
      # @return [Boolean] true if type is "ssd"
      def ssd?
        type == "ssd"
      end

      # Checks if disk has a GPT partition table.
      #
      # @return [Boolean] true if gpt is 1
      def gpt?
        gpt == 1
      end

      # Checks if disk is currently mounted.
      #
      # @return [Boolean] true if mounted is 1
      def mounted?
        mounted == 1
      end

      # Checks if disk is a Ceph OSD.
      #
      # @return [Boolean] true if osdid is non-nil and >= 0
      def osd?
        !osdid.nil? && osdid >= 0
      end

      # Merges SMART data into the model.
      #
      # Called after initial construction when SMART data is fetched separately
      # from the disk list endpoint.
      #
      # @param smart_data [Hash{Symbol => untyped}] SMART response data
      # @return [void]
      def merge_smart(smart_data)
        @smart_type = smart_data[:type]
        @smart_attributes = smart_data[:attributes]
        @smart_text = smart_data[:text]
        @wearout = smart_data[:wearout]
        @health = smart_data[:health] if smart_data[:health]
      end
    end
  end
end
