# frozen_string_literal: true

module Pvectl
  module Models
    # Represents the contents of /etc/hosts on a Proxmox node.
    #
    # Immutable value object. Created by Repositories::Hosts from API data.
    # /etc/hosts is a per-node raw text file — pvectl does not parse or
    # validate its contents.
    #
    # @example Creating from API response
    #   hosts = HostsFile.new(node: "pve1",
    #                         data: "127.0.0.1 localhost\n",
    #                         digest: "abc123")
    #
    # @see Pvectl::Repositories::Hosts Repository that creates HostsFile instances
    # @see Pvectl::Presenters::HostsFile Presenter for formatting HostsFile data
    #
    class HostsFile < Base
      # @return [String, nil] node name (not part of API payload — added by repository)
      attr_reader :node

      # @return [String] raw /etc/hosts content (may be empty)
      attr_reader :data

      # @return [String, nil] digest used for optimistic locking on update
      attr_reader :digest

      # Creates a new HostsFile.
      #
      # @param attributes [Hash] attribute key-value pairs (node, data, digest)
      def initialize(attributes = {})
        super
        @node = attributes[:node] || attributes["node"]
        @data = attributes[:data] || attributes["data"] || ""
        @digest = attributes[:digest] || attributes["digest"]
      end

      # Number of lines in the file (for compact list display).
      #
      # @return [Integer] line count
      def line_count
        data.lines.count
      end
    end
  end
end
