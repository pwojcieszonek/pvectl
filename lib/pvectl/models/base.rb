# frozen_string_literal: true

module Pvectl
  module Models
    # Abstract base class for domain models.
    #
    # Provides common initialization from hash attributes.
    # All models are immutable - only getters, no setters.
    #
    # Subclasses store domain data and contain domain logic,
    # but do not fetch data themselves (that's the Repository's job).
    #
    # @abstract Subclass and add attr_readers for domain attributes.
    #
    # @example Implementing a model
    #   class Vm < Base
    #     attr_reader :vmid, :name, :status
    #
    #     def initialize(attributes = {})
    #       super
    #       @vmid = attributes[:vmid]
    #       @name = attributes[:name]
    #       @status = attributes[:status]
    #     end
    #
    #     def running?
    #       status == "running"
    #     end
    #   end
    #
    # @see Pvectl::Repositories::Base Repository creates model instances
    #
    class Base
      # Creates model from attributes hash.
      #
      # Converts string keys to symbols for consistent access.
      #
      # @param attributes [Hash] attribute key-value pairs
      def initialize(attributes = {})
        @attributes = (attributes || {}).transform_keys(&:to_sym)
      end

      protected

      # @return [Hash] the raw attributes hash
      attr_reader :attributes
    end
  end
end
