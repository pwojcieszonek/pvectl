# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for per-node DNS resolver settings.
    #
    # Uses the `/nodes/{node}/dns` endpoint to fetch and update
    # the DNS configuration of a single node.
    #
    # @example Fetching DNS config
    #   repo = Dns.new(connection)
    #   dns = repo.fetch("pve1")
    #   dns.servers #=> ["8.8.8.8"]
    #
    # @example Updating DNS config
    #   repo.update("pve1", search: "example.com", dns1: "8.8.8.8")
    #
    # @see Pvectl::Models::DnsConfig DNS configuration model
    #
    class Dns < Base
      # Fetches the DNS configuration for a node.
      #
      # @param node_name [String] node name
      # @return [Models::DnsConfig] DNS configuration model
      def fetch(node_name)
        response = connection.client["nodes/#{node_name}/dns"].get
        data = extract_data(response) || {}
        build_model(data.merge(node: node_name))
      end

      # Updates the DNS configuration for a node.
      #
      # The Proxmox PUT endpoint requires `search` and accepts optional
      # `dns1`, `dns2`, `dns3`. Only provided keys are sent.
      #
      # @param node_name [String] node name
      # @param params [Hash] update parameters (:search, :dns1, :dns2, :dns3)
      # @return [void]
      def update(node_name, params = {})
        connection.client["nodes/#{node_name}/dns"].put(params)
      end

      protected

      # Builds DnsConfig model from API data.
      #
      # @param data [Hash] API response hash (must include :node key for context)
      # @return [Models::DnsConfig] DNS configuration model
      def build_model(data)
        Models::DnsConfig.new(data)
      end
    end
  end
end
