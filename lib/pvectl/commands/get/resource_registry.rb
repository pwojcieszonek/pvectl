# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      # Registry for Get command resource handlers.
      #
      # Inherits all registration and lookup logic from Commands::ResourceRegistry.
      # Each handler registers itself at load time.
      #
      # @example Looking up a handler
      #   handler = ResourceRegistry.for("nodes")
      #   handler.list(node: "pve1") if handler
      #
      class ResourceRegistry < Commands::ResourceRegistry; end
    end
  end
end
