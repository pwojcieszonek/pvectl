# frozen_string_literal: true

module Pvectl
  module Commands
    # Resolves a list of CLI identifiers (VMIDs and/or names) to models for
    # multi-target commands (lifecycle, delete, template).
    #
    # Lists once (honoring the --node filter), applies {Utils::IdentifierMatcher}
    # to each identifier, and returns the deduplicated union. A name may resolve
    # to several models; downstream confirmation prompts guard bulk actions.
    #
    # Expects the includer to define @resource_ids (Array) and @options (Hash).
    #
    module IdentifierResolution
      private

      # @param repo [#list] resource repository
      # @return [Array] matched models, deduplicated by VMID
      def resolve_identifiers_against(repo)
        all = repo.list(node: @options[:node])
        @resource_ids
          .flat_map { |id| Utils::IdentifierMatcher.match(id, all) }
          .uniq(&:vmid)
      end
    end
  end
end
