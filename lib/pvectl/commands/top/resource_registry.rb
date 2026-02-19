# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      # Registry for Top command resource handlers.
      #
      # Inherits registration and lookup from Commands::ResourceRegistry,
      # maintaining its own isolated set of handlers.
      #
      # @example Registering a handler
      #   Top::ResourceRegistry.register("nodes", Handlers::Nodes, aliases: ["node"])
      #
      # @example Looking up a handler
      #   handler = Top::ResourceRegistry.for("nodes")
      #
      # @see Pvectl::Commands::ResourceRegistry Base registry
      #
      class ResourceRegistry < Commands::ResourceRegistry; end
    end
  end
end
