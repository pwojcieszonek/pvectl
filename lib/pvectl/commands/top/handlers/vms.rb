# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      module Handlers
        # Handler for Top command VM metrics display.
        #
        # Wraps Get::Handlers::Vms to fetch VM data and pairs it
        # with TopVm presenter for metrics-focused output.
        #
        # @example Using via ResourceRegistry
        #   handler = Top::ResourceRegistry.for("vms")
        #   vms = handler.list(sort: "cpu")
        #   presenter = handler.presenter
        #
        # @see Pvectl::Commands::Get::Handlers::Vms Get handler
        # @see Pvectl::Presenters::TopVm Top presenter
        #
        class Vms
          include Top::ResourceHandler

          # Creates handler with optional Get handler for dependency injection.
          #
          # @param get_handler [Get::Handlers::Vms, nil] handler (default: create new)
          def initialize(get_handler: nil)
            @get_handler = get_handler
          end

          # Lists VMs with optional sorting.
          #
          # @param sort [String, nil] sort field (cpu, memory, disk)
          # @return [Array<Models::Vm>] collection of VM models
          def list(sort: nil, **_)
            get_handler.list(sort: sort)
          end

          # Returns Top-specific presenter for VMs.
          #
          # @return [Presenters::TopVm] TopVm presenter instance
          def presenter
            Presenters::TopVm.new
          end

          private

          # Returns Get handler, creating it if necessary.
          #
          # @return [Get::Handlers::Vms] Vms get handler
          def get_handler
            @get_handler ||= Get::Handlers::Vms.new
          end
        end
      end
    end
  end
end

Pvectl::Commands::Top::ResourceRegistry.register(
  "vms", Pvectl::Commands::Top::Handlers::Vms, aliases: ["vm"]
)
