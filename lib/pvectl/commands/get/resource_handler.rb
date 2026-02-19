# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      # Interface module for resource handlers.
      #
      # Each resource type (nodes, vms, containers, storage) implements
      # this interface to provide listing capabilities.
      #
      # Minimal interface with two methods:
      # - #list - fetches and returns model objects
      # - #presenter - returns presenter for formatting
      #
      # @abstract Include in handler class and implement required methods.
      #
      # @example Implementing a handler
      #   class NodesHandler
      #     include ResourceHandler
      #
      #     def list(node: nil, name: nil)
      #       # Fetch and return array of Node models
      #       repository.list.select { |n| name.nil? || n.name == name }
      #     end
      #
      #     def presenter
      #       Presenters::Node.new
      #     end
      #   end
      #
      module ResourceHandler
        # Lists resources, optionally filtered by node and name.
        #
        # @param node [String, nil] filter by node name (for VMs/containers)
        # @param name [String, nil] filter by resource name
        # @return [Array<Object>] collection of model objects
        # @raise [NotImplementedError] if not implemented by including class
        def list(node: nil, name: nil)
          raise NotImplementedError, "#{self.class}#list must be implemented"
        end

        # Returns the presenter for this resource type.
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
