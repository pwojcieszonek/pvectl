# frozen_string_literal: true

module Pvectl
  module Repositories
    # Abstract base class for repositories.
    #
    # Repositories encapsulate Proxmox API communication and are responsible
    # for converting raw API data to domain models. Each repository handles
    # one resource type (VMs, Containers, Nodes, etc.).
    #
    # @abstract Subclass and implement {#list}, {#get}, and {#build_model}.
    #
    # @example Implementing a repository
    #   class Vm < Base
    #     def list(node: nil)
    #       response = connection.client["cluster/resources"].get(params: { type: "vm" })
    #       response.map { |data| build_model(data) }
    #     end
    #
    #     def get(vmid)
    #       list.find { |vm| vm.vmid == vmid.to_i }
    #     end
    #
    #     protected
    #
    #     def build_model(data)
    #       Models::Vm.new(data)
    #     end
    #   end
    #
    # @see Pvectl::Connection API connection wrapper
    # @see Pvectl::Models::Base Model base class
    #
    class Base
      # Creates repository with connection.
      #
      # @param connection [Connection] Proxmox API connection
      def initialize(connection)
        @connection = connection
      end

      # Lists all resources.
      #
      # @return [Array<Models::Base>] collection of models
      # @raise [NotImplementedError] if not implemented by subclass
      def list
        raise NotImplementedError, "#{self.class}#list must be implemented"
      end

      # Gets a single resource by ID.
      #
      # @param id [String, Integer] resource identifier
      # @return [Models::Base, nil] model or nil if not found
      # @raise [NotImplementedError] if not implemented by subclass
      def get(id)
        raise NotImplementedError, "#{self.class}#get must be implemented"
      end

      protected

      # @return [Connection] the API connection
      attr_reader :connection

      # Builds model from API response data.
      #
      # @param data [Hash] API response hash
      # @return [Models::Base] model instance
      # @raise [NotImplementedError] if not implemented by subclass
      def build_model(data)
        raise NotImplementedError, "#{self.class}#build_model must be implemented"
      end

      # Unwraps API response to array format.
      # Handles: Array (passthrough), Hash with :data key, Hash without :data.
      #
      # @param response [Array, Hash, nil] API response
      # @return [Array] unwrapped array
      def unwrap(response)
        case response
        when Array then response
        when Hash then response[:data] || response.to_a
        when nil then []
        else response.to_a
        end
      end

      # Extracts data from hash response.
      # If response has :data key, returns its value. Otherwise returns response.
      #
      # @param response [Hash, Object] API response
      # @return [Hash, Object] extracted data
      def extract_data(response)
        return response unless response.is_a?(Hash)

        response[:data] || response
      end

      # Creates model instances from API response.
      #
      # @param response [Array, Hash, nil] API response (will be unwrapped)
      # @param model_class [Class] model class to instantiate
      # @return [Array] array of model instances
      def models_from(response, model_class)
        return [] if response.nil?

        unwrap(response).map { |data| model_class.new(data) }
      end
    end
  end
end
