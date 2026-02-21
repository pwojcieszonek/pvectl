# frozen_string_literal: true

module Pvectl
  module Models
    # Wraps snapshot describe data: target snapshot + siblings for tree building.
    #
    # Used by the describe command to return rich snapshot data without
    # changing the existing single-model return convention in ResourceService.
    #
    # @example Single VM
    #   desc = SnapshotDescription.new(entries: [
    #     SnapshotDescription::Entry.new(snapshot: snap, siblings: all_snaps)
    #   ])
    #
    # @example Multiple VMs
    #   desc = SnapshotDescription.new(entries: [entry1, entry2])
    #   desc.single? # => false
    #
    class SnapshotDescription
      # Holds a single snapshot + its siblings for one VM/container.
      Entry = Struct.new(:snapshot, :siblings, keyword_init: true)

      # @return [Array<Entry>] entries per VM/container
      attr_reader :entries

      # @param entries [Array<Entry>] snapshot entries
      def initialize(entries:)
        @entries = entries
      end

      # Returns true when describing a snapshot from a single VM.
      #
      # @return [Boolean]
      def single?
        entries.length == 1
      end
    end
  end
end
