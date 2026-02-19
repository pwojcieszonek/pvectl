# frozen_string_literal: true

module Pvectl
  module Commands
    # Abstract base class for command resource registries.
    #
    # Provides handler registration and lookup. Each subclass maintains
    # its own isolated set of handlers via +self.inherited+ callback.
    #
    # @abstract Subclass for each command namespace (Get, Top, Logs).
    #
    # @example Creating a command-specific registry
    #   module Pvectl::Commands::Logs
    #     class ResourceRegistry < Pvectl::Commands::ResourceRegistry; end
    #   end
    #
    class ResourceRegistry
      @handlers = {}

      def self.inherited(subclass)
        super
        subclass.instance_variable_set(:@handlers, {})
      end

      class << self
        # Registers a handler class for a resource type.
        #
        # @param resource_type [String, Symbol] primary resource type name
        # @param handler_class [Class] handler class
        # @param aliases [Array<String, Symbol>] alternative names
        # @return [void]
        def register(resource_type, handler_class, aliases: [])
          @handlers[resource_type.to_s] = handler_class
          aliases.each { |a| @handlers[a.to_s] = handler_class }
        end

        # Returns a new handler instance for the resource type.
        #
        # @param resource_type [String, Symbol, nil] resource type name
        # @return [Object, nil] handler instance or nil
        def for(resource_type)
          return nil if resource_type.nil?

          handler_class = @handlers[resource_type.to_s]
          handler_class&.new
        end

        # Returns all registered type names (including aliases).
        #
        # @return [Array<String>] registered type names
        def registered_types
          @handlers.keys
        end

        # Checks if a resource type is registered.
        #
        # @param resource_type [String, Symbol] resource type name
        # @return [Boolean]
        def registered?(resource_type)
          @handlers.key?(resource_type.to_s)
        end

        # Clears all registered handlers.
        #
        # @return [void]
        # @api private
        def reset!
          @handlers = {}
        end
      end
    end
  end
end
