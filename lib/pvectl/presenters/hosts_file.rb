# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for per-node /etc/hosts content.
    #
    # /etc/hosts is raw text — pvectl does not attempt to parse it.
    # In table mode only summary metadata is shown (node, line count, digest).
    # JSON/YAML output exposes the raw `data` string. Describe output
    # prints the full content under a "Content" key.
    #
    # @see Pvectl::Models::HostsFile HostsFile model
    #
    class HostsFile < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE LINES DIGEST]
      end

      # Converts HostsFile model to table row values.
      #
      # @param model [Models::HostsFile] HostsFile model
      # @param _context [Hash] optional context (unused)
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.node || "-",
          model.line_count.to_s,
          model.digest || "-"
        ]
      end

      # Converts HostsFile model to hash for JSON/YAML output.
      #
      # @param model [Models::HostsFile] HostsFile model
      # @return [Hash] hash representation with string keys
      def to_hash(model)
        {
          "node" => model.node,
          "data" => model.data,
          "digest" => model.digest
        }
      end

      # Converts HostsFile model to describe format (kubectl-style).
      #
      # @param model [Models::HostsFile] HostsFile model
      # @return [Hash] structured hash for describe formatter
      def to_description(model)
        {
          "Node" => model.node || "-",
          "Digest" => model.digest || "-",
          "Lines" => model.line_count.to_s,
          "Content" => model.data.empty? ? "(empty)" : model.data
        }
      end
    end
  end
end
