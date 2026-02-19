# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      module Handlers
        # Handler for Top command node metrics display.
        #
        # Wraps Get::Handlers::Nodes to fetch node data and pairs it
        # with TopNode presenter for metrics-focused output.
        #
        # @example Using via ResourceRegistry
        #   handler = Top::ResourceRegistry.for("nodes")
        #   nodes = handler.list(sort: "cpu")
        #   presenter = handler.presenter
        #
        # @see Pvectl::Commands::Get::Handlers::Nodes Get handler
        # @see Pvectl::Presenters::TopNode Top presenter
        #
        class Nodes
          include Top::ResourceHandler

          # Creates handler with optional Get handler for dependency injection.
          #
          # @param get_handler [Get::Handlers::Nodes, nil] handler (default: create new)
          def initialize(get_handler: nil)
            @get_handler = get_handler
          end

          # Lists nodes with optional sorting.
          #
          # @param sort [String, nil] sort field (cpu, memory, disk)
          # @return [Array<Models::Node>] collection of Node models
          def list(sort: nil, **_)
            get_handler.list(sort: sort)
          end

          # Returns Top-specific presenter for nodes.
          #
          # @return [Presenters::TopNode] TopNode presenter instance
          def presenter
            Presenters::TopNode.new
          end

          private

          # Returns Get handler, creating it if necessary.
          #
          # @return [Get::Handlers::Nodes] Nodes get handler
          def get_handler
            @get_handler ||= Get::Handlers::Nodes.new
          end
        end
      end
    end
  end
end

Pvectl::Commands::Top::ResourceRegistry.register(
  "nodes", Pvectl::Commands::Top::Handlers::Nodes, aliases: ["node"]
)
