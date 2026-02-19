# frozen_string_literal: true

module Pvectl
  module Commands
    module Top
      # Interface module for Top command handlers.
      #
      # Each handler wraps a Get handler and returns a Top-specific presenter
      # for metrics-focused display (CPU%, MEM%, etc.).
      #
      # @abstract Include in handler class and implement required methods.
      #
      # @example Implementing a handler
      #   class NodesHandler
      #     include Top::ResourceHandler
      #
      #     def list(sort: nil, **_)
      #       get_handler.list(sort: sort)
      #     end
      #
      #     def presenter
      #       Presenters::TopNode.new
      #     end
      #   end
      #
      module ResourceHandler
        # Lists resources with optional sorting.
        #
        # @param options [Hash] keyword arguments (e.g., sort:)
        # @return [Array<Object>] collection of model objects
        # @raise [NotImplementedError] if not implemented by including class
        def list(**options)
          raise NotImplementedError, "#{self.class}#list must be implemented"
        end

        # Returns the Top-specific presenter for this resource type.
        #
        # @return [Presenters::Base] presenter instance
        # @raise [NotImplementedError] if not implemented by including class
        def presenter
          raise NotImplementedError, "#{self.class}#presenter must be implemented"
        end
      end
    end
  end
end
