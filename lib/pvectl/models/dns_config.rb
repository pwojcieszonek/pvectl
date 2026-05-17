# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the DNS resolver configuration for a Proxmox node.
    #
    # Immutable value object. Created by Repositories::Dns from API data.
    # Each node has its own DNS settings — there is no cluster-wide DNS config.
    #
    # @example Creating from API response
    #   dns = DnsConfig.new(node: "pve1", search: "example.com",
    #                       dns1: "8.8.8.8", dns2: "1.1.1.1")
    #   dns.servers #=> ["8.8.8.8", "1.1.1.1"]
    #
    # @see Pvectl::Repositories::Dns Repository that creates DnsConfig instances
    # @see Pvectl::Presenters::DnsConfig Presenter for formatting DnsConfig data
    #
    class DnsConfig < Base
      # @return [String, nil] node name (not part of the API payload — added by repository)
      attr_reader :node

      # @return [String, nil] search domain for hostname lookup
      attr_reader :search

      # @return [String, nil] first nameserver IP address
      attr_reader :dns1

      # @return [String, nil] second nameserver IP address (optional)
      attr_reader :dns2

      # @return [String, nil] third nameserver IP address (optional)
      attr_reader :dns3

      # Creates a new DnsConfig.
      #
      # @param attributes [Hash] attribute key-value pairs (node, search, dns1, dns2, dns3)
      def initialize(attributes = {})
        super
        @node = attributes[:node] || attributes["node"]
        @search = attributes[:search] || attributes["search"]
        @dns1 = attributes[:dns1] || attributes["dns1"]
        @dns2 = attributes[:dns2] || attributes["dns2"]
        @dns3 = attributes[:dns3] || attributes["dns3"]
      end

      # Returns the configured DNS servers in order, omitting unset entries.
      #
      # @return [Array<String>] nameserver IP addresses (may be empty)
      def servers
        [dns1, dns2, dns3].compact
      end
    end
  end
end
