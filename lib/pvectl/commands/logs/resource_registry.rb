# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      # Registry for Logs command resource handlers.
      #
      # Inherits registration and lookup from Commands::ResourceRegistry,
      # maintaining its own isolated set of handlers for log operations.
      #
      # @example Registering a handler
      #   Logs::ResourceRegistry.register("vm", Handlers::TaskLogs, aliases: ["vms"])
      #
      # @example Looking up a handler
      #   handler = Logs::ResourceRegistry.for("vm")
      #
      # @see Pvectl::Commands::ResourceRegistry Base registry
      #
      class ResourceRegistry < Commands::ResourceRegistry; end
    end
  end
end
