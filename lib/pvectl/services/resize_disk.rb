# frozen_string_literal: true

module Pvectl
  module Services
    # Orchestrates disk resize operations for VMs and containers.
    #
    # Handles size parsing, preflight validation (current size comparison),
    # and execution via the repository interface. Works polymorphically with
    # both VM and Container repositories (they share #fetch_config and #resize).
    #
    # Two-phase operation:
    # 1. {#preflight} — validates disk exists, computes new size, checks constraints
    # 2. {#perform} — executes the actual resize via repository
    #
    # @example Basic resize flow
    #   parsed = ResizeDisk.parse_size("+10G")
    #   service = ResizeDisk.new(repository: vm_repo)
    #   info = service.preflight(100, "scsi0", parsed, node: "pve1")
    #   result = service.perform(100, "scsi0", parsed.raw, node: "pve1")
    #
    class ResizeDisk
      # Raised when the specified disk key is not found in resource config.
      class DiskNotFoundError < StandardError; end

      # Raised when absolute size is not larger than current disk size.
      class SizeTooSmallError < StandardError; end

      # Parsed size representation returned by {.parse_size}.
      #
      # @!attribute [r] relative
      #   @return [Boolean] true if size is relative (prefixed with +)
      # @!attribute [r] value
      #   @return [String] clean size value without + prefix (e.g., "10G")
      # @!attribute [r] raw
      #   @return [String] original size string for API (e.g., "+10G")
      ParsedSize = Struct.new(:relative, :value, :raw, keyword_init: true) do
        # Whether this is a relative size (increment).
        #
        # @return [Boolean]
        def relative?
          relative
        end
      end

      # Size regex: optional +, digits with optional decimal, optional T/G/M/K suffix.
      SIZE_PATTERN = /\A(\+)?(\d+(?:\.\d+)?)([TGMK])?\z/i

      # Multipliers for converting units to megabytes (MB as base unit).
      UNIT_MULTIPLIERS = {
        "T" => 1024 * 1024,
        "G" => 1024,
        "M" => 1,
        "K" => 1.0 / 1024
      }.freeze

      # Parses a size string into a {ParsedSize}.
      #
      # Accepts formats like "10G", "+10G", "1.5T", "512M", "+100".
      # Suffix is uppercased. No suffix means raw number.
      #
      # @param size_str [String] size string to parse
      # @return [ParsedSize] parsed size components
      # @raise [ArgumentError] if format is invalid, empty, or negative
      #
      # @example Relative size
      #   ResizeDisk.parse_size("+10G")
      #   #=> ParsedSize(relative: true, value: "10G", raw: "+10G")
      #
      # @example Absolute size
      #   ResizeDisk.parse_size("50G")
      #   #=> ParsedSize(relative: false, value: "50G", raw: "50G")
      def self.parse_size(size_str)
        raise ArgumentError, "Size cannot be empty" if size_str.nil? || size_str.strip.empty?

        match = SIZE_PATTERN.match(size_str.strip)
        raise ArgumentError, "Invalid size format: #{size_str}" unless match

        plus, number, suffix = match.captures
        suffix = suffix&.upcase

        raise ArgumentError, "Size must be positive: #{size_str}" if number.to_f <= 0

        clean_value = "#{number}#{suffix}"
        raw_value = "#{plus}#{number}#{suffix}"

        ParsedSize.new(
          relative: !plus.nil?,
          value: clean_value,
          raw: raw_value
        )
      end

      # Creates a new ResizeDisk service.
      #
      # @param repository [Repositories::Vm, Repositories::Container] resource repository
      def initialize(repository:)
        @repository = repository
      end

      # Validates the resize operation and returns size information.
      #
      # Checks that the disk exists in the resource config, extracts current
      # size, calculates new size, and validates constraints (absolute must
      # be larger than current).
      #
      # @param id [Integer] resource identifier (VMID or CTID)
      # @param disk [String] disk key (e.g., "scsi0", "rootfs", "mp0")
      # @param parsed_size [ParsedSize] parsed size from {.parse_size}
      # @param node [String] node name
      # @return [Hash] preflight info with :disk, :current_size, :new_size
      # @raise [DiskNotFoundError] if disk not in config or size not extractable
      # @raise [SizeTooSmallError] if absolute size <= current size
      def preflight(id, disk, parsed_size, node:)
        config = @repository.fetch_config(node, id)
        current_size = extract_disk_size(config, disk, id)
        new_size = calculate_new_size(current_size, parsed_size)
        validate_new_size!(current_size, new_size, parsed_size)

        { disk: disk, current_size: current_size, new_size: new_size }
      end

      # Executes the disk resize via repository.
      #
      # @param id [Integer] resource identifier (VMID or CTID)
      # @param disk [String] disk key
      # @param raw_size [String] size string for API (e.g., "+10G", "50G")
      # @param node [String] node name
      # @return [Models::OperationResult] operation result
      def perform(id, disk, raw_size, node:)
        @repository.resize(id, node, disk: disk, size: raw_size)
        Models::OperationResult.new(
          operation: :resize_disk,
          success: true,
          resource: { id: id, node: node, disk: disk, size: raw_size }
        )
      rescue StandardError => e
        Models::OperationResult.new(
          operation: :resize_disk,
          success: false,
          error: e.message,
          resource: { id: id, node: node, disk: disk }
        )
      end

      private

      # Extracts the disk size from a config value string.
      #
      # Config values have formats like:
      # - VM:        "local-lvm:vm-100-disk-0,size=32G"
      # - Container: "local-lvm:subvol-100-disk-0,size=8G"
      # - Rootfs:    "local-lvm:subvol-100-disk-0,size=8G"
      #
      # @param config [Hash] resource configuration
      # @param disk [String] disk key to look up
      # @param id [Integer] resource ID (for error messages)
      # @return [String] current size (e.g., "32G")
      # @raise [DiskNotFoundError] if disk not found or size not extractable
      def extract_disk_size(config, disk, id)
        disk_value = config[disk.to_sym]
        raise DiskNotFoundError, "Disk '#{disk}' not found in config for resource #{id}" unless disk_value

        size_match = disk_value.to_s.match(/size=(\d+(?:\.\d+)?[TGMK]?)/i)
        raise DiskNotFoundError, "Cannot determine size for disk '#{disk}' on resource #{id}" unless size_match

        size_match[1]
      end

      # Calculates the new size after resize.
      #
      # For relative sizes, adds the increment to current size (converting
      # units as needed). For absolute sizes, returns the parsed value directly.
      #
      # @param current_size [String] current size (e.g., "32G")
      # @param parsed_size [ParsedSize] parsed size
      # @return [String] new size (e.g., "42G")
      def calculate_new_size(current_size, parsed_size)
        if parsed_size.relative?
          current_num, current_suffix = parse_size_components(current_size)
          add_num, add_suffix = parse_size_components(parsed_size.value)

          converted_add = convert_to_unit(add_num, add_suffix, current_suffix)
          new_num = current_num + converted_add

          format_size(new_num, current_suffix)
        else
          parsed_size.value
        end
      end

      # Validates that the new size is larger than current for absolute resizes.
      #
      # Relative sizes always pass (Proxmox enforces positive increments).
      # Absolute sizes must be strictly larger than current.
      #
      # @param current_size [String] current size
      # @param new_size [String] new size
      # @param parsed_size [ParsedSize] parsed size (to check if relative)
      # @raise [SizeTooSmallError] if absolute size <= current
      def validate_new_size!(current_size, new_size, parsed_size)
        return if parsed_size.relative?

        if size_to_bytes(new_size) <= size_to_bytes(current_size)
          raise SizeTooSmallError,
                "New size #{new_size} must be larger than current size #{current_size}"
        end
      end

      # Parses size string into numeric value and unit suffix.
      #
      # @param size [String] size string (e.g., "32G", "1.5T", "100")
      # @return [Array(Float, String)] number and suffix (defaults to "G")
      def parse_size_components(size)
        match = size.to_s.match(/\A(\d+(?:\.\d+)?)([TGMK])?\z/i)
        return [0.0, "G"] unless match

        [match[1].to_f, (match[2] || "G").upcase]
      end

      # Converts a value from one unit to another using MB as base.
      #
      # @param value [Float] numeric value
      # @param from_unit [String] source unit (T, G, M, K)
      # @param to_unit [String] target unit (T, G, M, K)
      # @return [Float] converted value
      def convert_to_unit(value, from_unit, to_unit)
        mb_value = value * UNIT_MULTIPLIERS.fetch(from_unit, 1024)
        mb_value / UNIT_MULTIPLIERS.fetch(to_unit, 1024)
      end

      # Formats a numeric value and suffix into a size string.
      #
      # Produces integer format when possible (e.g., "42G" not "42.0G").
      #
      # @param value [Float] numeric value
      # @param suffix [String] unit suffix
      # @return [String] formatted size (e.g., "42G")
      def format_size(value, suffix)
        formatted = value == value.to_i ? value.to_i.to_s : format("%.1f", value)
        "#{formatted}#{suffix}"
      end

      # Converts a size string to bytes for comparison.
      #
      # @param size [String] size string (e.g., "32G")
      # @return [Float] size in bytes
      def size_to_bytes(size)
        num, suffix = parse_size_components(size)
        num * UNIT_MULTIPLIERS.fetch(suffix, 1024) * 1024 * 1024 # MB to bytes
      end
    end
  end
end
