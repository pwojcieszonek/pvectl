# frozen_string_literal: true

module Pvectl
  module Parsers
    # Parses and converts cloud-init configuration strings for Proxmox VMs.
    #
    # CloudInitConfig handles the conversion between user-friendly key=value
    # cloud-init specifications and the parameter names required by the Proxmox API.
    # Unlike DiskConfig and NetConfig, all keys are optional.
    #
    # @example Parsing a cloud-init config string
    #   config = CloudInitConfig.parse("user=admin,password=secret,ip=dhcp")
    #   config[:user]     #=> "admin"
    #   config[:password]  #=> "secret"
    #   config[:ip]        #=> "dhcp"
    #
    # @example Converting to Proxmox API parameters
    #   config = { user: "admin", ip: "dhcp" }
    #   CloudInitConfig.to_proxmox_params(config)
    #   #=> { ciuser: "admin", ipconfig0: "ip=dhcp" }
    #
    class CloudInitConfig
      # All recognized cloud-init configuration keys.
      VALID_KEYS = %w[user password sshkeys ip gw nameserver searchdomain].freeze

      # Parses a comma-separated key=value cloud-init config string into a Hash.
      #
      # @param string [String] cloud-init config in "key=value,key=value" format
      # @return [Hash<Symbol, String>] parsed configuration
      # @raise [ArgumentError] if unknown keys are present
      #
      # @example
      #   CloudInitConfig.parse("user=admin,ip=dhcp,nameserver=8.8.8.8")
      #   #=> { user: "admin", ip: "dhcp", nameserver: "8.8.8.8" }
      def self.parse(string)
        pairs = string.split(",").map { |pair| pair.strip.split("=", 2).map(&:strip) }
        config = pairs.to_h { |k, v| [k.to_sym, v] }

        validate!(config)
        config
      end

      # Converts a parsed cloud-init config Hash to Proxmox API parameter names.
      #
      # Maps user-friendly keys to their Proxmox API equivalents:
      # - +user+ becomes +ciuser+
      # - +password+ becomes +cipassword+
      # - +sshkeys+ stays +sshkeys+
      # - +ip+ becomes +ipconfig0+ with "ip=" prefix
      # - +nameserver+ stays +nameserver+
      # - +searchdomain+ stays +searchdomain+
      #
      # @param config [Hash<Symbol, String>] parsed cloud-init configuration
      # @return [Hash<Symbol, String>] Proxmox API parameters
      #
      # @example Minimal config
      #   CloudInitConfig.to_proxmox_params({ user: "admin" })
      #   #=> { ciuser: "admin" }
      #
      # @example With IP and nameserver
      #   CloudInitConfig.to_proxmox_params({ ip: "dhcp", nameserver: "8.8.8.8" })
      #   #=> { ipconfig0: "ip=dhcp", nameserver: "8.8.8.8" }
      def self.to_proxmox_params(config)
        params = {}
        params[:ciuser] = config[:user] if config[:user]
        params[:cipassword] = config[:password] if config[:password]
        params[:sshkeys] = config[:sshkeys] if config[:sshkeys]
        if config[:ip]
          ip_str = "ip=#{config[:ip]}"
          ip_str += ",gw=#{config[:gw]}" if config[:gw]
          params[:ipconfig0] = ip_str
        end
        params[:nameserver] = config[:nameserver] if config[:nameserver]
        params[:searchdomain] = config[:searchdomain] if config[:searchdomain]
        params
      end

      # Validates that config contains only known keys.
      #
      # @param config [Hash<Symbol, String>] parsed cloud-init configuration
      # @return [void]
      # @raise [ArgumentError] if unknown keys are present
      def self.validate!(config)
        unknown = config.keys.map(&:to_s) - VALID_KEYS
        unless unknown.empty?
          raise ArgumentError, "Unknown cloud-init config key(s): #{unknown.join(', ')}"
        end
      end
      private_class_method :validate!
    end
  end
end
