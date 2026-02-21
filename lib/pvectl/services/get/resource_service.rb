# frozen_string_literal: true

module Pvectl
  module Services
    module Get
      # Service for fetching and formatting resource data.
      #
      # Orchestrates the data flow between:
      # - ResourceHandler (provides models and presenter)
      # - Formatters::Registry (formats output)
      #
      # This follows ARCHITECTURE.md section 3.4:
      # "Services orchestrate data flow between Repository, Models, and Formatters"
      #
      # @example Basic usage
      #   handler = ResourceRegistry.for("nodes")
      #   service = ResourceService.new(handler: handler, format: "table")
      #   output = service.list(node: "pve1")
      #   puts output
      #
      class ResourceService
        # Creates a new ResourceService.
        #
        # @param handler [ResourceHandler] the resource handler for data fetching
        # @param format [String] output format (table, json, yaml, wide)
        # @param color_enabled [Boolean] whether to enable colored output
        def initialize(handler:, format: "table", color_enabled: true)
          @handler = handler
          @format = format
          @color_enabled = color_enabled
        end

        # Fetches and formats resources.
        #
        # @param node [String, nil] filter by node name
        # @param name [String, nil] filter by resource name
        # @param args [Array<String>] additional positional arguments (e.g., VMIDs for snapshots)
        # @param storage [String, nil] filter by storage (for backups)
        # @param options [Hash] additional options passed through to handler (e.g., limit, since, type_filter)
        # @return [String] formatted output string
        def list(node: nil, name: nil, args: [], storage: nil, **options)
          models = @handler.list(node: node, name: name, args: args, storage: storage, **options)
          presenter = @handler.presenter
          format_output(models, presenter)
        end

        # Describes and formats a single resource.
        #
        # For local storage with multiple instances, returns list of nodes
        # when no node specified, or full describe when node is specified.
        #
        # @param name [String] resource name
        # @param node [String, nil] filter by node name (for local storage)
        # @return [String] formatted output string
        def describe(name:, node: nil, args: [])
          result = @handler.describe(name: name, node: node, args: args)
          presenter = @handler.presenter

          if result.is_a?(Array)
            # Multiple instances - format as list
            format_output(result, presenter)
          else
            # Single model - format as describe
            format_output_describe(result, presenter)
          end
        end

        private

        attr_reader :handler, :format, :color_enabled

        # Formats models for output using the appropriate formatter.
        #
        # @param models [Array<Object>] collection of models
        # @param presenter [Presenters::Base] presenter for the resource type
        # @return [String] formatted output
        def format_output(models, presenter)
          formatter = Formatters::Registry.for(format)
          formatter.format(models, presenter, color_enabled: color_enabled)
        end

        # Formats single model for describe output.
        #
        # @param model [Object] single model
        # @param presenter [Presenters::Base] presenter for the resource type
        # @return [String] formatted output
        def format_output_describe(model, presenter)
          formatter = Formatters::Registry.for(format)
          formatter.format(model, presenter, color_enabled: color_enabled, describe: true)
        end
      end
    end
  end
end
