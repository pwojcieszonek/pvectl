# frozen_string_literal: true

module Pvectl
  module Formatters
    # Abstract base class for output formatters.
    #
    # Formatters implement the Strategy Pattern, converting model data
    # to various output formats (table, json, yaml, wide).
    #
    # @abstract Subclass and implement {#format} to create a formatter.
    #
    # @example Implementing a custom formatter
    #   class MyFormatter < Base
    #     def format(data, presenter, color_enabled: true, **context)
    #       # Return formatted string
    #     end
    #   end
    #
    # @see Pvectl::Formatters::Registry for looking up formatters by name
    # @see Pvectl::Presenters::Base for presenter interface
    #
    class Base
      # Formats data for output.
      #
      # @param data [Array, Object] collection of models or single model
      # @param presenter [Presenters::Base] presenter for column/row definitions
      # @param color_enabled [Boolean] whether to apply color formatting
      # @param context [Hash] additional context (e.g., current_context for contexts)
      # @return [String] formatted output string
      # @raise [NotImplementedError] if not implemented by subclass
      def format(data, presenter, color_enabled: true, **context)
        raise NotImplementedError, "#{self.class}#format must be implemented"
      end

      protected

      # Determines if data is a collection or single resource.
      #
      # @param data [Array, Object] data to check
      # @return [Boolean] true if data is a collection (Array)
      def collection?(data)
        data.is_a?(Array)
      end

      # Normalizes nil values for display.
      #
      # @param value [Object, nil] value to normalize
      # @param nil_placeholder [String] placeholder for nil values (default: "-")
      # @return [Object, String] original value or placeholder
      def normalize_nil(value, nil_placeholder = "-")
        value.nil? ? nil_placeholder : value
      end
    end
  end
end
