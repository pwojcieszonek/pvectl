# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for per-node DNS resolver configuration.
    #
    # Defines column layout for table output and structured data for
    # JSON/YAML and describe output. DNS is a singleton resource per node.
    #
    # @example Using with formatter
    #   presenter = DnsConfig.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format([dns_model], presenter)
    #
    # @see Pvectl::Models::DnsConfig DnsConfig model
    #
    class DnsConfig < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE SEARCH DNS1 DNS2 DNS3]
      end

      # Converts DnsConfig model to table row values.
      #
      # @param model [Models::DnsConfig] DNS configuration model
      # @param _context [Hash] optional context (unused)
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.node || "-",
          model.search || "-",
          model.dns1 || "-",
          model.dns2 || "-",
          model.dns3 || "-"
        ]
      end

      # Converts DnsConfig model to hash for JSON/YAML output.
      #
      # @param model [Models::DnsConfig] DNS configuration model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        {
          "node" => model.node,
          "search" => model.search,
          "dns1" => model.dns1,
          "dns2" => model.dns2,
          "dns3" => model.dns3
        }
      end

      # Converts DnsConfig model to describe format (kubectl-style).
      #
      # @param model [Models::DnsConfig] DNS configuration model
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        servers = model.servers
        {
          "Node" => model.node || "-",
          "Search Domain" => model.search || "-",
          "Nameservers" => servers.empty? ? "-" : servers
        }
      end
    end
  end
end
