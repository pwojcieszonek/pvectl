# frozen_string_literal: true

module Pvectl
  module Selectors
    # Selector for filtering containers.
    #
    # Extends Base with container-specific field extraction.
    # Supports: status, tags, pool, name.
    #
    # @example Filter running containers
    #   selector = Container.parse("status=running")
    #   running_containers = selector.apply(all_containers)
    #
    # @example Filter by multiple criteria
    #   selector = Container.parse("status=running,tags=prod")
    #   filtered = selector.apply(all_containers)
    #
    # @example Filter by name pattern
    #   selector = Container.parse("name=~web-*")
    #   web_containers = selector.apply(all_containers)
    #
    class Container < Base
      SUPPORTED_FIELDS = %w[status tags pool name].freeze

      # Applies selector to container collection.
      #
      # @param containers [Array<Models::Container>] Containers to filter
      # @return [Array<Models::Container>] Filtered containers
      def apply(containers)
        return containers if empty?

        containers.select { |ct| matches?(ct) }
      end

      protected

      # Extracts field value from Container model.
      #
      # @param container [Models::Container] Container model
      # @param field [String] Field name (status, tags, pool, name)
      # @return [String, nil] Field value
      # @raise [ArgumentError] if field is not supported
      def extract_value(container, field)
        case field
        when "status"
          container.status
        when "tags"
          container.tags
        when "pool"
          container.pool
        when "name"
          container.name
        else
          raise ArgumentError, "Unknown field: #{field}. Supported: #{SUPPORTED_FIELDS.join(', ')}"
        end
      end

      # Override to handle tags specially.
      # Tags in Proxmox are semicolon-separated: "tag1;tag2;tag3"
      # Selector "tags=prod" should match if "prod" is one of the tags.
      #
      # @param container [Models::Container] Container model
      # @param condition [Hash] Condition
      # @return [Boolean] true if matches
      def match_condition?(container, condition)
        return match_tags_condition?(container, condition) if condition[:field] == "tags"

        super
      end

      private

      # Special matching for tags field.
      # Proxmox tags are semicolon-separated, so we check if the value
      # is contained in the tag list.
      #
      # @param container [Models::Container] Container model
      # @param condition [Hash] Condition
      # @return [Boolean] true if matches
      def match_tags_condition?(container, condition)
        tags_string = container.tags || ""
        tag_list = tags_string.split(";").map(&:strip)

        case condition[:operator]
        when :eq
          tag_list.include?(condition[:value])
        when :neq
          !tag_list.include?(condition[:value])
        when :match
          tag_list.any? { |tag| wildcard_match?(tag, condition[:value]) }
        when :in
          (tag_list & condition[:value]).any?
        else
          false
        end
      end
    end
  end
end
