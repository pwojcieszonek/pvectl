# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      module Handlers
        # Handler for Top command container metrics display.
        #
        # Wraps Get::Handlers::Containers to fetch container data and pairs it
        # with TopContainer presenter for metrics-focused output.
        #
        # @example Using via ResourceRegistry
        #   handler = Top::ResourceRegistry.for("containers")
        #   containers = handler.list(sort: "cpu")
        #   presenter = handler.presenter
        #
        # @see Pvectl::Commands::Get::Handlers::Containers Get handler
        # @see Pvectl::Presenters::TopContainer Top presenter
        #
        class Containers
          include Top::ResourceHandler

          # Creates handler with optional Get handler for dependency injection.
          #
          # @param get_handler [Get::Handlers::Containers, nil] handler (default: create new)
          def initialize(get_handler: nil)
            @get_handler = get_handler
          end

          # Lists containers with optional sorting.
          #
          # @param sort [String, nil] sort field (cpu, memory, disk)
          # @return [Array<Models::Container>] collection of Container models
          def list(sort: nil, **_)
            get_handler.list(sort: sort)
          end

          # Returns Top-specific presenter for containers.
          #
          # @return [Presenters::TopContainer] TopContainer presenter instance
          def presenter
            Presenters::TopContainer.new
          end

          private

          # Returns Get handler, creating it if necessary.
          #
          # @return [Get::Handlers::Containers] Containers get handler
          def get_handler
            @get_handler ||= Get::Handlers::Containers.new
          end
        end
      end
    end
  end
end

Pvectl::Commands::Top::ResourceRegistry.register(
  "containers", Pvectl::Commands::Top::Handlers::Containers, aliases: ["container", "cts", "ct"]
)
