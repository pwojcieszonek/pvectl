# frozen_string_literal: true

module Pvectl
  module Formatters
    # Registry for looking up formatters by name.
    #
    # Implements the Registry Pattern to map format names
    # ("table", "json", "yaml", "wide") to formatter classes.
    #
    # @example Getting a formatter
    #   formatter = Registry.for("json")
    #   output = formatter.format(data, presenter)
    #
    # @example Listing available formats
    #   Registry.available_formats #=> ["table", "wide", "json", "yaml"]
    #
    # @example Checking if format is supported
    #   Registry.supported?("json")  #=> true
    #   Registry.supported?("xml")   #=> false
    #
    class Registry
      # Mapping of format names to formatter classes.
      # @return [Hash<String, Class>] frozen hash of format name to class
      FORMATS = {
        "table" => Table,
        "wide" => Wide,
        "json" => Json,
        "yaml" => Yaml
      }.freeze

      class << self
        # Gets a formatter instance for the specified format.
        #
        # @param format_name [String, Symbol] format name (table, wide, json, yaml)
        # @return [Base] formatter instance
        # @raise [ArgumentError] if format is not found
        #
        # @example
        #   formatter = Registry.for("json")
        #   formatter.format(data, presenter)
        def for(format_name)
          formatter_class = FORMATS[format_name.to_s]
          raise ArgumentError, "Unknown format: #{format_name}" unless formatter_class

          formatter_class.new
        end

        # Returns list of available format names.
        #
        # @return [Array<String>] available format names
        #
        # @example
        #   Registry.available_formats #=> ["table", "wide", "json", "yaml"]
        def available_formats
          FORMATS.keys
        end

        # Checks if a format is supported.
        #
        # @param format_name [String, Symbol] format name
        # @return [Boolean] true if format is supported
        #
        # @example
        #   Registry.supported?("json")  #=> true
        #   Registry.supported?("xml")   #=> false
        def supported?(format_name)
          FORMATS.key?(format_name.to_s)
        end
      end
    end
  end
end
