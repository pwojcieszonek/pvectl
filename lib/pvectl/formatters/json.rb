# frozen_string_literal: true

require "json"

module Pvectl
  module Formatters
    # Formats data as JSON output.
    #
    # Collections are rendered as JSON arrays.
    # Single resources are rendered as JSON objects.
    # Empty collections return "[]".
    # Nil values are rendered as JSON null.
    #
    # @example JSON output for collection
    #   [
    #     {"name": "vm-100", "status": "running"},
    #     {"name": "vm-101", "status": "stopped"}
    #   ]
    #
    # @example JSON output for single resource
    #   {"name": "vm-100", "status": "running", "node": "pve1"}
    #
    class Json < Base
      # Formats data as JSON output.
      #
      # @param data [Array, Object] collection of models or single model
      # @param presenter [Presenters::Base] presenter for hash conversion
      # @param color_enabled [Boolean] ignored for JSON (always plain text)
      # @param describe [Boolean] whether this is a describe command
      # @param context [Hash] ignored for JSON output
      # @return [String] formatted JSON string (pretty-printed)
      def format(data, presenter, color_enabled: true, describe: false, **context)
        if describe && !collection?(data)
          # Use to_description for describe mode
          JSON.pretty_generate(presenter.to_description(data))
        elsif collection?(data)
          hashes = data.map { |model| presenter.to_hash(model) }
          JSON.pretty_generate(hashes)
        else
          JSON.pretty_generate(presenter.to_hash(data))
        end
      end
    end
  end
end
