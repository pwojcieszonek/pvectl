# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a network interface on a Proxmox node.
    #
    # Immutable domain model containing network interface attributes and helper
    # methods for display. Created by Repositories::Node from API data.
    #
    # @example Creating a NetworkInterface model
    #   iface = NetworkInterface.new(iface: "vmbr0", type: "bridge")
    #   iface.active? #=> true
    #
    # @example From API response
    #   data = { "iface" => "vmbr0", "type" => "bridge", "address" => "192.168.1.10/24" }
    #   iface = NetworkInterface.new(data)
    #
    # @see Pvectl::Repositories::Node Repository that creates NetworkInterface instances
    #
    class NetworkInterface < Base
      # @return [String] interface name (e.g., "vmbr0", "eth0")
      attr_reader :iface

      # @return [String] interface type (bridge, bond, eth, vlan)
      attr_reader :type

      # @return [String, nil] IP address with CIDR (e.g., "192.168.1.10/24")
      attr_reader :address

      # @return [String, nil] gateway IP address
      attr_reader :gateway

      # @return [Integer] active flag (0/1)
      attr_reader :active

      # @return [Integer] autostart flag (0/1)
      attr_reader :autostart

      # @return [String, nil] bridge ports (for bridge type)
      attr_reader :bridge_ports

      # @return [String, nil] comments
      attr_reader :comments

      # Creates a new NetworkInterface model from attributes.
      #
      # @param attrs [Hash] NetworkInterface attributes from API (string or symbol keys)
      def initialize(attrs = {})
        super
        @iface = attributes[:iface]
        @type = attributes[:type]
        @address = attributes[:address]
        @gateway = attributes[:gateway]
        @active = attributes[:active]
        @autostart = attributes[:autostart]
        @bridge_ports = attributes[:bridge_ports]
        @comments = attributes[:comments]
      end

      # Checks if the interface is active.
      #
      # @return [Boolean] true if active flag is 1
      def active?
        active == 1
      end

      # Checks if the interface has a gateway configured.
      #
      # @return [Boolean] true if gateway is present and non-empty
      def has_gateway?
        !gateway.nil? && !gateway.to_s.empty?
      end

      # Returns IP address without CIDR suffix.
      #
      # @return [String, nil] IP address without CIDR, or nil if address is nil
      # @example
      #   iface = NetworkInterface.new(address: "192.168.1.10/24")
      #   iface.ip_without_cidr #=> "192.168.1.10"
      def ip_without_cidr
        address&.split("/")&.first
      end
    end
  end
end
