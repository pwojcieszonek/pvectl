# frozen_string_literal: true

module Pvectl
  module Repositories
    # Adds VMID/name resolution to repositories that expose #list of models
    # responding to #vmid and #name (Vm, Container).
    #
    # Delegates the matching rule to {Utils::IdentifierMatcher} so VMID-first /
    # name-fallback semantics stay in one place.
    #
    module ResolvesByIdentifier
      # Resolves an identifier to all matching models (0..n).
      #
      # @param identifier [String, Integer] VMID or name
      # @return [Array<Models::Base>] matching models
      def resolve_identifier(identifier)
        Utils::IdentifierMatcher.match(identifier, list)
      end

      # Resolves an identifier to exactly one model.
      #
      # @param identifier [String, Integer] VMID or name
      # @return [Models::Base, nil] the single match, or nil if none
      # @raise [Pvectl::AmbiguousIdentifierError] if more than one match
      def resolve_one(identifier)
        matches = resolve_identifier(identifier)
        return nil if matches.empty?

        if matches.size > 1
          vmids = matches.map(&:vmid).join(", ")
          raise Pvectl::AmbiguousIdentifierError,
                "'#{identifier}' matches multiple resources (VMIDs #{vmids}) — specify a VMID"
        end

        matches.first
      end
    end
  end
end
