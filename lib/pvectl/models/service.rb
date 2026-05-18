# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a Proxmox service running on a node.
    #
    # Services are system daemons that make up the Proxmox VE platform,
    # such as pveproxy, pvedaemon, pve-cluster, etc.
    #
    # @example Creating a service instance
    #   service = Service.new(
    #     service: "pveproxy",
    #     name: "pveproxy",
    #     state: "running",
    #     desc: "PVE API Proxy Server"
    #   )
    #   service.running? # => true
    #
    # @see Pvectl::Repositories::Service Repository that creates these instances
    #
    class Service < Base
      # @return [String] the service identifier
      attr_reader :service

      # @return [String, nil] the display name of the service
      attr_reader :name

      # @return [String] the current state (running, stopped, etc.)
      attr_reader :state

      # @return [String, nil] the service description
      attr_reader :desc

      # @return [String, nil] systemd ActiveState (active, inactive, failed, ...)
      attr_reader :active_state

      # @return [String, nil] systemd UnitFileState (enabled, disabled, masked, ...)
      attr_reader :unit_state

      # @return [String, nil] node name this service belongs to
      attr_reader :node

      # Creates a new Service instance.
      #
      # @param attrs [Hash] service attributes
      # @option attrs [String] :service the service identifier
      # @option attrs [String] :name the display name
      # @option attrs [String] :state the current state
      # @option attrs [String] :desc the description
      # @option attrs [String] :active_state systemd ActiveState
      # @option attrs [String] :unit_state systemd UnitFileState
      # @option attrs [String] :node the node this service runs on
      def initialize(attrs = {})
        super
        @service = attributes[:service]
        @name = attributes[:name]
        @state = attributes[:state]
        @desc = attributes[:desc]
        # Accept both symbol keys (:active_state) and dasherized keys (:"active-state")
        @active_state = attributes[:active_state] || attributes[:"active-state"]
        @unit_state = attributes[:unit_state] || attributes[:"unit-state"]
        @node = attributes[:node]
      end

      # Checks if the service is currently running.
      #
      # @return [Boolean] true if state is "running"
      def running?
        state == "running"
      end

      # Returns the display name, falling back to service identifier.
      #
      # @return [String] the name to display
      def display_name
        name || service
      end
    end
  end
end
