# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses and formats network configuration strings for Proxmox VMs.
    #
    # NetConfig handles the conversion between user-friendly key=value
    # network specifications and the format required by the Proxmox API.
    #
    # @example Parsing a net config string
    #   config = NetConfig.parse("bridge=vmbr0,model=virtio,tag=100")
    #   config[:bridge] #=> "vmbr0"
    #   config[:model]  #=> "virtio"
    #   config[:tag]    #=> "100"
    #
    # @example Converting to Proxmox API format
    #   config = { bridge: "vmbr0", tag: "100" }
    #   NetConfig.to_proxmox(config) #=> "virtio,bridge=vmbr0,tag=100"
    #
    class NetConfig
      # All recognized network configuration keys.
      VALID_KEYS = %w[bridge model tag firewall mtu queues].freeze

      # Keys that must be present in every network configuration.
      REQUIRED_KEYS = %w[bridge].freeze

      # Optional flags appended to the Proxmox API string.
      OPTIONAL_FLAGS = %w[tag firewall mtu queues].freeze

      # Parses a comma-separated key=value net config string into a Hash.
      #
      # @param string [String] net config in "key=value,key=value" format
      # @return [Hash<Symbol, String>] parsed configuration
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      #
      # @example
      #   NetConfig.parse("bridge=vmbr0,model=virtio,tag=100")
      #   #=> { bridge: "vmbr0", model: "virtio", tag: "100" }
      def self.parse(string)
        pairs = string.split(",").map { |pair| pair.strip.split("=", 2).map(&:strip) }
        config = pairs.to_h { |k, v| [k.to_sym, v] }

        validate!(config)
        config
      end

      # Converts a parsed net config Hash to a Proxmox API string.
      #
      # The Proxmox API expects network specifications in the format
      # "model,bridge=name,flag=val". Model defaults to "virtio"
      # when not specified.
      #
      # @param config [Hash<Symbol, String>] parsed network configuration
      # @return [String] Proxmox API-compatible network string
      #
      # @example Minimal config
      #   NetConfig.to_proxmox({ bridge: "vmbr0" })
      #   #=> "virtio,bridge=vmbr0"
      #
      # @example With optional flags
      #   NetConfig.to_proxmox({ bridge: "vmbr0", tag: "100", firewall: "1" })
      #   #=> "virtio,bridge=vmbr0,tag=100,firewall=1"
      def self.to_proxmox(config)
        model = config[:model] || "virtio"
        parts = [model, "bridge=#{config[:bridge]}"]

        OPTIONAL_FLAGS.each do |flag|
          parts << "#{flag}=#{config[flag.to_sym]}" if config[flag.to_sym]
        end

        parts.join(",")
      end

      # Validates that config contains only known keys and all required keys.
      #
      # @param config [Hash<Symbol, String>] parsed network configuration
      # @return [void]
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      def self.validate!(config)
        unknown = config.keys.map(&:to_s) - VALID_KEYS
        unless unknown.empty?
          raise ArgumentError, "Unknown net config key(s): #{unknown.join(', ')}"
        end

        REQUIRED_KEYS.each do |key|
          value = config[key.to_sym]
          if value.nil? || value.strip.empty?
            raise ArgumentError, "Missing required net config key: #{key}"
          end
        end
      end
      private_class_method :validate!
    end
  end
end
