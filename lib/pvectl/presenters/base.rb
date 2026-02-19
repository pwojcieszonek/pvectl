# frozen_string_literal: true

module Pvectl
  module Presenters
    # Abstract base class for resource presenters.
    #
    # Presenters define how models are displayed in different formats.
    # Each resource type (VM, Container, Node, etc.) has its own presenter.
    #
    # @abstract Subclass and implement {#columns}, {#to_row}, and {#to_hash}.
    #
    # @example Implementing a resource presenter
    #   class VmPresenter < Base
    #     def columns
    #       ["NAME", "STATUS", "NODE"]
    #     end
    #
    #     def extra_columns
    #       ["MEMORY", "CPU"]
    #     end
    #
    #     def to_row(model, **context)
    #       [model.name, model.status, model.node]
    #     end
    #
    #     def extra_values(model, **context)
    #       [model.memory, model.cpu]
    #     end
    #
    #     def to_hash(model)
    #       { "name" => model.name, "status" => model.status, "node" => model.node }
    #     end
    #   end
    #
    # @see Pvectl::Formatters::OutputHelper for using presenters with formatters
    #
    class Base
      # Returns column headers for table format.
      #
      # @return [Array<String>] column names (uppercase, e.g., ["NAME", "STATUS"])
      # @raise [NotImplementedError] if not implemented by subclass
      def columns
        raise NotImplementedError, "#{self.class}#columns must be implemented"
      end

      # Returns extended column headers for wide format.
      # By default, appends extra_columns to columns.
      #
      # @return [Array<String>] column names (normal + extra)
      def wide_columns
        columns + extra_columns
      end

      # Returns additional columns for wide format.
      # Override in subclass to add extra columns.
      #
      # @return [Array<String>] extra column names (empty by default)
      def extra_columns
        []
      end

      # Converts model to table row values.
      #
      # @param model [Object] domain model object
      # @param context [Hash] optional context (e.g., current_context: "prod")
      # @return [Array<String, nil>] row values matching columns order
      # @raise [NotImplementedError] if not implemented by subclass
      def to_row(model, **context)
        raise NotImplementedError, "#{self.class}#to_row must be implemented"
      end

      # Converts model to wide table row values.
      # By default, appends extra_values to to_row.
      #
      # @param model [Object] domain model object
      # @param context [Hash] optional context
      # @return [Array<String, nil>] row values (normal + extra)
      def to_wide_row(model, **context)
        to_row(model, **context) + extra_values(model, **context)
      end

      # Returns additional values for wide format.
      # Override in subclass to add extra values.
      #
      # @param model [Object] domain model object
      # @param context [Hash] optional context
      # @return [Array<String, nil>] extra values (empty by default)
      def extra_values(model, **context)
        []
      end

      # Converts model to hash for JSON/YAML format.
      #
      # @param model [Object] domain model object
      # @return [Hash] hash representation with string keys
      # @raise [NotImplementedError] if not implemented by subclass
      def to_hash(model)
        raise NotImplementedError, "#{self.class}#to_hash must be implemented"
      end

      # Converts model to description format (kubectl-style vertical layout).
      # By default, delegates to to_hash. Override for custom describe output.
      #
      # @param model [Object] domain model object
      # @return [Hash] hash representation (keys become labels)
      def to_description(model)
        to_hash(model)
      end
    end
  end
end
