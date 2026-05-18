# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for Proxmox node time and timezone settings.
    #
    # Wraps the `/nodes/{node}/time` API endpoint:
    # - GET fetches `{time, localtime, timezone}`
    # - PUT sets the timezone (the only writable field)
    #
    # @example Fetching time
    #   repo = TimeConfig.new(connection)
    #   config = repo.fetch("pve1")
    #   config.timezone #=> "Europe/Warsaw"
    #
    # @example Setting timezone
    #   repo.set_timezone("pve1", "UTC")
    #
    # @see Pvectl::Models::TimeConfig Model returned by #fetch
    #
    class TimeConfig < Base
      # Fetches time and timezone settings for a node.
      #
      # @param node_name [String] cluster node name
      # @return [Models::TimeConfig] time configuration for the node
      def fetch(node_name)
        response = connection.client["nodes/#{node_name}/time"].get
        data = extract_data(response) || {}
        build_model(data.merge(node_name: node_name))
      end

      # Sets the timezone on a node.
      #
      # @param node_name [String] cluster node name
      # @param timezone [String] IANA timezone identifier (e.g., "Europe/Warsaw")
      # @return [nil] Proxmox returns null on success
      def set_timezone(node_name, timezone)
        connection.client["nodes/#{node_name}/time"].put(timezone: timezone)
        nil
      end

      protected

      # Builds TimeConfig model from API data.
      #
      # @param data [Hash] API response merged with `:node_name`
      # @return [Models::TimeConfig]
      def build_model(data)
        Models::TimeConfig.new(data)
      end
    end
  end
end
