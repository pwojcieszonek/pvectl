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
    #     health: "PASSED"
    #   )
    #   disk.ssd?      # => true
    #   disk.healthy?  # => true
    #   disk.size_gb   # => 465.7
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
      def initialize(attrs = {})
        super
        @devpath = attributes[:devpath]
        @model = attributes[:model]
        @size = attributes[:size]
        @type = attributes[:type]
        @health = attributes[:health]
        @serial = attributes[:serial]
        @vendor = attributes[:vendor]
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
    end
  end
end
