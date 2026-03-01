# frozen_string_literal: true

require "yaml"

module Pvectl
  # Wraps ConfigSerializer output with a kubectl-like manifest envelope
  # (apiVersion, kind, metadata, spec). Handles bidirectional conversion
  # between YAML manifest files and internal config representations.
  module ManifestSerializer
    API_VERSION = "pvectl/v1"

    KINDS = {
      vm: "VirtualMachine",
      container: "Container"
    }.freeze

    KINDS_REVERSE = KINDS.invert.transform_keys(&:to_s).freeze

    class << self
      # Builds a YAML manifest string from nested config and metadata.
      #
      # @param nested_config [Hash] nested config from ConfigSerializer.to_nested
      # @param type [Symbol] :vm or :container
      # @param metadata [Hash] resource metadata (vmid, name, node, status, tags)
      # @return [String] YAML manifest string
      def to_yaml(nested_config, type:, metadata:)
        manifest = {
          "apiVersion" => API_VERSION,
          "kind" => KINDS.fetch(type),
          "metadata" => build_metadata(metadata),
          "spec" => stringify_keys_deep(nested_config)
        }

        YAML.dump(manifest)
      end

      private

      # Builds string-keyed metadata hash from symbol-keyed input.
      #
      # @param metadata [Hash] symbol-keyed metadata
      # @return [Hash] string-keyed metadata for YAML output
      def build_metadata(metadata)
        result = {}
        result["vmid"] = metadata[:vmid] if metadata[:vmid]
        result["name"] = metadata[:name] if metadata[:name]
        result["node"] = metadata[:node] if metadata[:node]
        result["status"] = metadata[:status] if metadata[:status]
        result["tags"] = metadata[:tags] if metadata[:tags]
        result
      end

      # Recursively converts symbol keys to string keys.
      #
      # @param hash [Hash] symbol-keyed hash
      # @return [Hash] string-keyed hash
      def stringify_keys_deep(hash)
        hash.transform_keys(&:to_s).transform_values do |v|
          v.is_a?(Hash) ? stringify_keys_deep(v) : v
        end
      end
    end
  end
end
