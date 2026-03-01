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

      # Parses a YAML manifest string into type, metadata, and spec.
      #
      # @param yaml_string [String] YAML manifest
      # @return [Hash] { type: Symbol, metadata: Hash, spec: Hash }
      def from_yaml(yaml_string)
        parsed = YAML.safe_load(yaml_string)
        type = KINDS_REVERSE[parsed["kind"]]

        {
          type: type,
          metadata: symbolize_metadata(parsed["metadata"] || {}),
          spec: symbolize_keys_deep(parsed["spec"] || {})
        }
      end

      # Validates manifest structure (envelope only, not spec content).
      #
      # @param yaml_string [String] YAML manifest
      # @return [Array<String>] error messages (empty if valid)
      def validate(yaml_string)
        errors = []

        begin
          parsed = YAML.safe_load(yaml_string)
        rescue Psych::SyntaxError => e
          return ["YAML syntax error: #{e.message}"]
        end

        unless parsed.is_a?(Hash)
          return ["Invalid manifest: expected a YAML mapping"]
        end

        unless parsed["apiVersion"]
          errors << "Missing required field 'apiVersion'"
        end

        if parsed["apiVersion"] && parsed["apiVersion"] != API_VERSION
          errors << "Unsupported apiVersion '#{parsed["apiVersion"]}'. Expected: #{API_VERSION}"
        end

        errors << "Missing required field 'kind'" unless parsed["kind"]

        if parsed["kind"] && !KINDS_REVERSE.key?(parsed["kind"])
          errors << "Unknown kind '#{parsed["kind"]}'. Valid: #{KINDS.values.join(', ')}"
        end

        metadata = parsed["metadata"]
        if metadata.nil? || !metadata.is_a?(Hash)
          errors << "Missing required field 'metadata'"
        elsif !metadata.key?("vmid")
          errors << "Missing required field 'metadata.vmid'"
        end

        errors
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

      # Converts string-keyed metadata to symbol-keyed hash.
      #
      # @param hash [Hash] string-keyed metadata from YAML
      # @return [Hash] symbol-keyed metadata
      def symbolize_metadata(hash)
        result = {}
        result[:vmid] = hash["vmid"] if hash["vmid"]
        result[:name] = hash["name"] if hash["name"]
        result[:node] = hash["node"] if hash["node"]
        result[:status] = hash["status"] if hash["status"]
        result[:tags] = hash["tags"] if hash["tags"]
        result
      end

      # Recursively converts string keys to symbol keys.
      #
      # @param hash [Hash] string-keyed hash from YAML
      # @return [Hash] symbol-keyed hash
      def symbolize_keys_deep(hash)
        hash.to_h do |k, v|
          [k.to_sym, v.is_a?(Hash) ? symbolize_keys_deep(v) : v]
        end
      end
    end
  end
end
