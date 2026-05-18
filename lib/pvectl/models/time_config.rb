# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the time and timezone settings of a Proxmox node.
    #
    # Immutable value object holding the response from `GET /nodes/{node}/time`,
    # augmented with the node name (which is not part of the API payload but is
    # the identifying context for the lookup).
    #
    # Display formatting is handled by Presenters::TimeConfig.
    #
    # @example Creating from API data
    #   data = { time: 1_715_000_000, localtime: 1_715_007_200, timezone: "Europe/Warsaw" }
    #   model = TimeConfig.new(data.merge(node_name: "pve1"))
    #   model.timezone #=> "Europe/Warsaw"
    #
    # @see Pvectl::Repositories::TimeConfig Repository that creates instances
    # @see Pvectl::Presenters::TimeConfig Presenter for formatting
    #
    class TimeConfig < Base
      # @return [String, nil] node name (identifies which node this config belongs to)
      attr_reader :node_name

      # @return [Integer, nil] seconds since epoch (UTC)
      attr_reader :time

      # @return [Integer, nil] seconds since epoch interpreted as the node's local
      #   wall clock (Proxmox returns the local clock encoded as if it were UTC).
      attr_reader :localtime

      # @return [String, nil] IANA timezone name (e.g., "Europe/Warsaw", "UTC")
      attr_reader :timezone

      # Creates a new TimeConfig.
      #
      # @param attributes [Hash] attribute key-value pairs
      def initialize(attributes = {})
        super
        @node_name = @attributes[:node_name]
        @time = @attributes[:time]
        @localtime = @attributes[:localtime]
        @timezone = @attributes[:timezone]
      end
    end
  end
end
