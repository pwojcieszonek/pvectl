# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses and formats LXC network configurations for Proxmox containers.
    #
    # LXC network format differs from QEMU: uses name/type instead of model,
    # and supports IP configuration directly in the network spec.
    #
    # @example Parsing a net config string
    #   config = LxcNetConfig.parse("bridge=vmbr0,name=eth0,ip=dhcp")
    #   config[:bridge] #=> "vmbr0"
    #   config[:name]   #=> "eth0"
    #   config[:ip]     #=> "dhcp"
    #
    # @example Converting to Proxmox API format
    #   LxcNetConfig.to_proxmox({ bridge: "vmbr0", ip: "dhcp" })
    #   #=> "name=eth0,bridge=vmbr0,ip=dhcp,type=veth"
    #
    class LxcNetConfig
      # All recognized LXC network configuration keys.
      VALID_KEYS = %w[bridge name ip gw ip6 gw6 tag firewall mtu rate type].freeze

      # Keys that must be present in every network configuration.
      REQUIRED_KEYS = %w[bridge].freeze

      # Optional flags appended to the Proxmox API string.
      OPTIONAL_FLAGS = %w[ip gw ip6 gw6 tag firewall mtu rate].freeze

      # Parses a comma-separated key=value LXC net config string into a Hash.
      #
      # @param string [String] net config in "key=value,key=value" format
      # @return [Hash<Symbol, String>] parsed configuration
      # @raise [ArgumentError] if unknown keys are present or required keys are missing
      #
      # @example
      #   LxcNetConfig.parse("bridge=vmbr0,name=eth0,ip=dhcp")
      #   #=> { bridge: "vmbr0", name: "eth0", ip: "dhcp" }
      def self.parse(string)
        pairs = string.split(",").map { |pair| pair.strip.split("=", 2).map(&:strip) }
        config = pairs.to_h { |k, v| [k.to_sym, v] }

        validate!(config)
        config
      end

      # Converts a parsed LXC net config Hash to a Proxmox API string.
      #
      # The Proxmox API expects LXC network specifications in the format
      # "name=eth0,bridge=vmbr0,[flags],type=veth". Name defaults to "eth0"
      # and type defaults to "veth" when not specified.
      #
      # @param config [Hash<Symbol, String>] parsed network configuration
      # @return [String] Proxmox API-compatible network string
      #
      # @example Minimal config
      #   LxcNetConfig.to_proxmox({ bridge: "vmbr0" })
      #   #=> "name=eth0,bridge=vmbr0,type=veth"
      #
      # @example With IP and gateway
      #   LxcNetConfig.to_proxmox({ bridge: "vmbr0", ip: "10.0.0.5/24", gw: "10.0.0.1" })
      #   #=> "name=eth0,bridge=vmbr0,ip=10.0.0.5/24,gw=10.0.0.1,type=veth"
      def self.to_proxmox(config)
        name = config[:name] || "eth0"
        type = config[:type] || "veth"
        parts = ["name=#{name}", "bridge=#{config[:bridge]}"]

        OPTIONAL_FLAGS.each do |flag|
          parts << "#{flag}=#{config[flag.to_sym]}" if config[flag.to_sym]
        end

        parts << "type=#{type}"
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
          raise ArgumentError, "Unknown LXC net config key(s): #{unknown.join(', ')}"
        end

        REQUIRED_KEYS.each do |key|
          value = config[key.to_sym]
          if value.nil? || value.strip.empty?
            raise ArgumentError, "Missing required LXC net config key: #{key}"
          end
        end
      end
      private_class_method :validate!
    end
  end
end
