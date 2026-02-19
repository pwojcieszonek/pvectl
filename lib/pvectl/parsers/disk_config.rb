# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses and formats disk configuration strings for Proxmox VMs.
    #
    # DiskConfig handles the conversion between user-friendly key=value
    # disk specifications and the format required by the Proxmox API.
    #
    # @example Parsing a disk config string
    #   config = DiskConfig.parse("storage=local-lvm,size=32G,format=qcow2")
    #   config[:storage] #=> "local-lvm"
    #   config[:size]    #=> "32G"
    #   config[:format]  #=> "qcow2"
    #
    # @example Converting to Proxmox API format
    #   config = { storage: "local-lvm", size: "32G", format: "qcow2" }
    #   DiskConfig.to_proxmox(config) #=> "local-lvm:32,format=qcow2"
    #
    class DiskConfig
      # All recognized disk configuration keys.
      VALID_KEYS = %w[storage size format cache discard ssd iothread backup].freeze

      # Keys that must be present in every disk configuration.
      REQUIRED_KEYS = %w[storage size].freeze

      # Optional flags appended to the Proxmox API string.
      OPTIONAL_FLAGS = %w[cache discard ssd iothread backup].freeze

      # Parses a comma-separated key=value disk config string into a Hash.
      #
      # @param string [String] disk config in "key=value,key=value" format
      # @return [Hash<Symbol, String>] parsed configuration
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      #
      # @example
      #   DiskConfig.parse("storage=local-lvm,size=32G")
      #   #=> { storage: "local-lvm", size: "32G" }
      def self.parse(string)
        pairs = string.split(",").map { |pair| pair.strip.split("=", 2).map(&:strip) }
        config = pairs.to_h { |k, v| [k.to_sym, v] }

        validate!(config)
        config
      end

      # Converts a parsed disk config Hash to a Proxmox API string.
      #
      # The Proxmox API expects disk specifications in the format
      # "storage:size,format=fmt,flag=val". Size is extracted as a
      # numeric value (without the "G" suffix). Format defaults to "raw"
      # when not specified.
      #
      # @param config [Hash<Symbol, String>] parsed disk configuration
      # @return [String] Proxmox API-compatible disk string
      #
      # @example Minimal config
      #   DiskConfig.to_proxmox({ storage: "local-lvm", size: "32G" })
      #   #=> "local-lvm:32,format=raw"
      #
      # @example With optional flags
      #   DiskConfig.to_proxmox({ storage: "local-lvm", size: "32G", cache: "writeback" })
      #   #=> "local-lvm:32,format=raw,cache=writeback"
      def self.to_proxmox(config)
        size_num = config[:size].to_s.gsub(/[^0-9]/, "")
        format = config[:format] || "raw"
        parts = ["#{config[:storage]}:#{size_num}", "format=#{format}"]

        OPTIONAL_FLAGS.each do |flag|
          parts << "#{flag}=#{config[flag.to_sym]}" if config[flag.to_sym]
        end

        parts.join(",")
      end

      # Validates that config contains only known keys and all required keys.
      #
      # @param config [Hash<Symbol, String>] parsed disk configuration
      # @return [void]
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      def self.validate!(config)
        unknown = config.keys.map(&:to_s) - VALID_KEYS
        unless unknown.empty?
          raise ArgumentError, "Unknown disk config key(s): #{unknown.join(', ')}"
        end

        REQUIRED_KEYS.each do |key|
          value = config[key.to_sym]
          if value.nil? || value.strip.empty?
            raise ArgumentError, "Missing required disk config key: #{key}"
          end
        end
      end
      private_class_method :validate!
    end
  end
end
