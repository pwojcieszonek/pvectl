# frozen_string_literal: true

module Pvectl
  module Selectors
    # Base class for parsing and applying selectors.
    #
    # Selectors use kubectl-style syntax to filter resources:
    #   -l key=value        # equality
    #   -l key!=value       # inequality
    #   -l key=~pattern     # wildcard pattern
    #   -l key in (a,b,c)   # one of many
    #
    # @example Parsing selectors
    #   selector = Base.parse("status=running,tags=prod")
    #   selector.conditions
    #   #=> [{field: "status", operator: :eq, value: "running"},
    #   #    {field: "tags", operator: :eq, value: "prod"}]
    #
    # @example Applying selectors (subclass responsibility)
    #   selector = Vm.parse("status=running")
    #   filtered = selector.apply(vms)
    #
    class Base
      # Parsed conditions
      # @return [Array<Hash>] Array of {field:, operator:, value:}
      attr_reader :conditions

      # Parses selector string into Base instance.
      #
      # @param selector_string [String] Selector like "status=running,tags=prod"
      # @return [Base] Selector instance with parsed conditions
      def self.parse(selector_string)
        new(parse_conditions(selector_string))
      end

      # Parses multiple selector strings (from multiple -l flags).
      #
      # @param selector_strings [Array<String>] Array of selector strings
      # @return [Base] Selector instance with all conditions merged
      def self.parse_all(selector_strings)
        conditions = selector_strings.flat_map { |s| parse_conditions(s) }
        new(conditions)
      end

      # Creates selector with parsed conditions.
      #
      # @param conditions [Array<Hash>] Pre-parsed conditions
      def initialize(conditions = [])
        @conditions = conditions
      end

      # Checks if selector is empty (no conditions).
      #
      # @return [Boolean] true if no conditions
      def empty?
        @conditions.empty?
      end

      # Applies selector to collection (subclass responsibility).
      #
      # @param collection [Array] Items to filter
      # @return [Array] Filtered items
      # @raise [NotImplementedError] if not implemented by subclass
      def apply(collection)
        raise NotImplementedError, "#{self.class}#apply must be implemented"
      end

      # Checks if a single item matches all conditions.
      #
      # @param item [Object] Item to check
      # @return [Boolean] true if all conditions match
      def matches?(item)
        @conditions.all? { |cond| match_condition?(item, cond) }
      end

      protected

      # Checks if item matches a single condition.
      # Subclasses should override to extract field values from items.
      #
      # @param item [Object] Item to check
      # @param condition [Hash] Condition with :field, :operator, :value
      # @return [Boolean] true if condition matches
      def match_condition?(item, condition)
        actual_value = extract_value(item, condition[:field])
        compare_value(actual_value, condition[:operator], condition[:value])
      end

      # Extracts field value from item (subclass responsibility).
      #
      # @param item [Object] Item
      # @param field [String] Field name
      # @return [Object] Field value
      # @raise [NotImplementedError] if not implemented by subclass
      def extract_value(item, field)
        raise NotImplementedError, "#{self.class}#extract_value must be implemented"
      end

      # Compares actual value against expected using operator.
      #
      # @param actual [Object] Actual value from item
      # @param operator [Symbol] :eq, :neq, :match, :in
      # @param expected [Object] Expected value (String or Array for :in)
      # @return [Boolean] true if comparison passes
      def compare_value(actual, operator, expected)
        case operator
        when :eq
          actual.to_s == expected.to_s
        when :neq
          actual.to_s != expected.to_s
        when :match
          wildcard_match?(actual.to_s, expected.to_s)
        when :in
          expected.any? { |v| actual.to_s == v.to_s }
        else
          false
        end
      end

      # Matches string against wildcard pattern.
      # Converts * to regex .* for matching.
      #
      # @param value [String] Value to match
      # @param pattern [String] Wildcard pattern (e.g., "web-*")
      # @return [Boolean] true if matches
      def wildcard_match?(value, pattern)
        regex = Regexp.new("\\A" + Regexp.escape(pattern).gsub("\\*", ".*") + "\\z")
        regex.match?(value)
      end

      # Class method to parse conditions from string.
      def self.parse_conditions(selector_string)
        return [] if selector_string.nil? || selector_string.empty?

        # Split by comma (but not inside parentheses)
        parts = split_selectors(selector_string)
        parts.map { |part| parse_single_condition(part.strip) }
      end

      # Splits selector string by commas, respecting parentheses.
      def self.split_selectors(str)
        parts = []
        current = ""
        depth = 0

        str.each_char do |char|
          case char
          when "("
            depth += 1
            current += char
          when ")"
            depth -= 1
            current += char
          when ","
            if depth == 0
              parts << current
              current = ""
            else
              current += char
            end
          else
            current += char
          end
        end

        parts << current unless current.empty?
        parts
      end

      # Parses a single condition like "status=running" or "status in (a,b)".
      def self.parse_single_condition(condition_str)
        # Try "in" operator first (has spaces)
        if condition_str =~ /\A(\w+)\s+in\s+\(([^)]+)\)\z/i
          field = Regexp.last_match(1)
          values = Regexp.last_match(2).split(",").map(&:strip)
          return { field: field, operator: :in, value: values }
        end

        # Try other operators
        if condition_str =~ /\A(\w+)(!=|=~|=)(.*)\z/
          field = Regexp.last_match(1)
          op_str = Regexp.last_match(2)
          value = Regexp.last_match(3).strip

          operator = case op_str
                     when "=" then :eq
                     when "!=" then :neq
                     when "=~" then :match
                     end

          return { field: field, operator: operator, value: value }
        end

        # Invalid syntax - raise error
        raise ArgumentError, "Invalid selector syntax: #{condition_str}"
      end

      private_class_method :parse_conditions, :split_selectors, :parse_single_condition
    end
  end
end
