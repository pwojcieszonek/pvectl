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

      # Returns uptime in human-readable format.
      # Delegates to resource.uptime. Override in subclasses with custom logic.
      #
      # @return [String] formatted uptime (e.g., "15d 3h") or "-"
      def uptime_human
        uptime = resource.uptime
        return "-" if uptime.nil? || uptime.zero?

        days = uptime / 86_400
        hours = (uptime % 86_400) / 3600
        minutes = (uptime % 3600) / 60

        if days.positive?
          "#{days}d #{hours}h"
        elsif hours.positive?
          "#{hours}h #{minutes}m"
        else
          "#{minutes}m"
        end
      end

      # Returns tags as array.
      #
      # @return [Array<String>] array of tags, or empty array if no tags
      def tags_array
        tags = resource.tags
        return [] if tags.nil? || tags.empty?

        tags.split(";").map(&:strip)
      end

      # Returns tags as comma-separated string.
      #
      # @return [String] formatted tags (e.g., "prod, web") or "-" if no tags
      def tags_display
        arr = tags_array
        arr.empty? ? "-" : arr.join(", ")
      end

      # Returns template display string.
      #
      # @return [String] "yes" if template, "-" otherwise
      def template_display
        resource.template? ? "yes" : "-"
      end

      private

      # Returns the current resource model.
      # Must be implemented by subclasses.
      #
      # @return [Object] current model
      # @raise [NotImplementedError] if not implemented
      def resource
        raise NotImplementedError, "#{self.class}#resource must be implemented"
      end

      # Formats bytes to human readable string.
      #
      # @param bytes [Integer, nil] bytes
      # @return [String] formatted size
      def format_bytes(bytes)
        return "-" if bytes.nil? || bytes.zero?

        if bytes >= 1024 * 1024 * 1024
          "#{(bytes.to_f / 1024 / 1024 / 1024).round(1)} GiB"
        elsif bytes >= 1024 * 1024
          "#{(bytes.to_f / 1024 / 1024).round(1)} MiB"
        elsif bytes >= 1024
          "#{(bytes.to_f / 1024).round(1)} KiB"
        else
          "#{bytes} B"
        end
      end
    end
  end
end
