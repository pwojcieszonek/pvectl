# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses and formats LXC mount configurations for Proxmox containers.
    #
    # Handles rootfs and mountpoint (mp0, mp1, ...) configuration strings.
    # Format: key=value pairs separated by commas.
    #
    # @example Parsing a rootfs config
    #   config = LxcMountConfig.parse("storage=local-lvm,size=8G")
    #   config[:storage] #=> "local-lvm"
    #   config[:size]    #=> "8G"
    #
    # @example Converting to Proxmox API format
    #   LxcMountConfig.to_proxmox({ storage: "local-lvm", size: "8G" })
    #   #=> "local-lvm:8"
    #
    #   LxcMountConfig.to_proxmox({ storage: "local-lvm", size: "32G", mp: "/mnt/data" })
    #   #=> "local-lvm:32,mp=/mnt/data"
    #
    class LxcMountConfig
      # All recognized mount configuration keys.
      VALID_KEYS = %w[storage size mp acl backup quota replicate ro shared].freeze

      # Keys that must be present in every mount configuration.
      REQUIRED_KEYS = %w[storage size].freeze

      # Optional flags appended to the Proxmox API string.
      OPTIONAL_FLAGS = %w[acl backup quota replicate ro shared].freeze

      # Parses a comma-separated key=value mount config string into a Hash.
      #
      # @param string [String] mount config in "key=value,key=value" format
      # @return [Hash<Symbol, String>] parsed configuration
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      #
      # @example
      #   LxcMountConfig.parse("storage=local-lvm,size=8G")
      #   #=> { storage: "local-lvm", size: "8G" }
      def self.parse(string)
        pairs = string.split(",").map { |pair| pair.strip.split("=", 2).map(&:strip) }
        config = pairs.to_h { |k, v| [k.to_sym, v] }

        validate!(config)
        config
      end

      # Converts a parsed mount config Hash to a Proxmox API string.
      #
      # The Proxmox API expects mount specifications in the format
      # "storage:size[,mp=/path][,flag=val]". Size is extracted as a
      # numeric value (without the "G" suffix).
      #
      # @param config [Hash<Symbol, String>] parsed mount configuration
      # @return [String] Proxmox API-compatible mount string
      #
      # @example Rootfs config
      #   LxcMountConfig.to_proxmox({ storage: "local-lvm", size: "8G" })
      #   #=> "local-lvm:8"
      #
      # @example Mountpoint with path and flags
      #   LxcMountConfig.to_proxmox({ storage: "local-lvm", size: "32G", mp: "/mnt/data", backup: "1" })
      #   #=> "local-lvm:32,mp=/mnt/data,backup=1"
      def self.to_proxmox(config)
        size_num = config[:size].to_s.gsub(/[^0-9]/, "")
        parts = ["#{config[:storage]}:#{size_num}"]
        parts << "mp=#{config[:mp]}" if config[:mp]

        OPTIONAL_FLAGS.each do |flag|
          parts << "#{flag}=#{config[flag.to_sym]}" if config[flag.to_sym]
        end

        parts.join(",")
      end

      # Validates that config contains only known keys and all required keys.
      #
      # @param config [Hash<Symbol, String>] parsed mount configuration
      # @return [void]
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      def self.validate!(config)
        unknown = config.keys.map(&:to_s) - VALID_KEYS
        unless unknown.empty?
          raise ArgumentError, "Unknown mount config key(s): #{unknown.join(', ')}"
        end

        REQUIRED_KEYS.each do |key|
          value = config[key.to_sym]
          if value.nil? || value.strip.empty?
            raise ArgumentError, "Missing required mount config key: #{key}"
          end
        end
      end
      private_class_method :validate!
    end
  end
end
