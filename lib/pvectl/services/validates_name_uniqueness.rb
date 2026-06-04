# frozen_string_literal: true

module Pvectl
  module Services
    # Adds cluster-wide name uniqueness validation to mutating services.
    #
    # The includer must set @name_resolver to an object responding to
    # #name_conflicts(name, except_vmid:) (a {Utils::ResourceResolver}). When
    # @name_resolver is nil the check is skipped, keeping the mixin
    # backward-compatible for callers/tests that do not inject one.
    #
    module ValidatesNameUniqueness
      private

      # Raises unless +name+ is free across all VMs and containers.
      #
      # @param name [String, nil] candidate name/hostname (blank = skip)
      # @param except_vmid [Integer, nil] VMID to ignore (renaming self)
      # @return [void]
      # @raise [Pvectl::DuplicateNameError] if the name is taken
      def ensure_name_available!(name, except_vmid: nil)
        return if name.nil? || name.to_s.empty?
        return unless @name_resolver

        conflicts = @name_resolver.name_conflicts(name, except_vmid: except_vmid)
        return if conflicts.empty?

        first = conflicts.first
        raise Pvectl::DuplicateNameError,
              "a VM or container named '#{name}' already exists " \
              "(VMID #{first[:vmid]} on #{first[:node]})"
      end
    end
  end
end
