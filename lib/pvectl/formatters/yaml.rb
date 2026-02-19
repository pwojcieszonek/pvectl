# frozen_string_literal: true

require "yaml"

module Pvectl
  module Formatters
    # Formats data as YAML output.
    #
    # Collections are rendered as YAML arrays.
    # Single resources are rendered as YAML mappings.
    # Empty collections return "--- []\n".
    # Nil values are rendered as YAML null (~).
    #
    # @example YAML output for collection
    #   ---
    #   - name: vm-100
    #     status: running
    #   - name: vm-101
    #     status: stopped
    #
    # @example YAML output for single resource
    #   ---
    #   name: vm-100
    #   status: running
    #   node: pve1
    #
    class Yaml < Base
      # Formats data as YAML output.
      #
      # @param data [Array, Object] collection of models or single model
      # @param presenter [Presenters::Base] presenter for hash conversion
      # @param color_enabled [Boolean] ignored for YAML (always plain text)
      # @param describe [Boolean] whether this is a describe command
      # @param context [Hash] ignored for YAML output
      # @return [String] formatted YAML string
      def format(data, presenter, color_enabled: true, describe: false, **context)
        if describe && !collection?(data)
          # Use to_description for describe mode
          presenter.to_description(data).to_yaml
        elsif collection?(data)
          hashes = data.map { |model| presenter.to_hash(model) }
          hashes.to_yaml
        else
          presenter.to_hash(data).to_yaml
        end
      end
    end
  end
end
