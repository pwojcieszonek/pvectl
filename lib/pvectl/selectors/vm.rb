# frozen_string_literal: true

module Pvectl
  module Selectors
    # Selector for filtering VMs.
    #
    # Extends Base with VM-specific field extraction.
    # Supports: status, tags, pool, name, template.
    #
    # @example Filter running VMs
    #   selector = Vm.parse("status=running")
    #   running_vms = selector.apply(all_vms)
    #
    # @example Filter by multiple criteria
    #   selector = Vm.parse("status=running,tags=prod")
    #   filtered = selector.apply(all_vms)
    #
    # @example Filter by name pattern
    #   selector = Vm.parse("name=~web-*")
    #   web_vms = selector.apply(all_vms)
    #
    class Vm < Base
      SUPPORTED_FIELDS = %w[status tags pool name template].freeze

      # Applies selector to VM collection.
      #
      # @param vms [Array<Models::Vm>] VMs to filter
      # @return [Array<Models::Vm>] Filtered VMs
      def apply(vms)
        return vms if empty?

        vms.select { |vm| matches?(vm) }
      end

      protected

      # Extracts field value from VM model.
      #
      # @param vm [Models::Vm] VM model
      # @param field [String] Field name (status, tags, pool, name, template)
      # @return [String, nil] Field value
      # @raise [ArgumentError] if field is not supported
      def extract_value(vm, field)
        case field
        when "status"
          vm.status
        when "tags"
          vm.tags
        when "pool"
          vm.pool
        when "name"
          vm.name
        when "template"
          vm.template? ? "yes" : "no"
        else
          raise ArgumentError, "Unknown field: #{field}. Supported: #{SUPPORTED_FIELDS.join(', ')}"
        end
      end

      # Override to handle tags specially.
      # Tags in Proxmox are semicolon-separated: "tag1;tag2;tag3"
      # Selector "tags=prod" should match if "prod" is one of the tags.
      #
      # @param vm [Models::Vm] VM model
      # @param condition [Hash] Condition
      # @return [Boolean] true if matches
      def match_condition?(vm, condition)
        return match_tags_condition?(vm, condition) if condition[:field] == "tags"

        super
      end

      private

      # Special matching for tags field.
      # Proxmox tags are semicolon-separated, so we check if the value
      # is contained in the tag list.
      #
      # @param vm [Models::Vm] VM model
      # @param condition [Hash] Condition
      # @return [Boolean] true if matches
      def match_tags_condition?(vm, condition)
        tags_string = vm.tags || ""
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
