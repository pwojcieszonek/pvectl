# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class SnapshotDescriptionTest < Minitest::Test
      def test_stores_entries
        snap = Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        siblings = [snap, Snapshot.new(name: "snap2", vmid: 100)]

        desc = SnapshotDescription.new(entries: [
          SnapshotDescription::Entry.new(snapshot: snap, siblings: siblings)
        ])

        assert_equal 1, desc.entries.length
        assert_equal "snap1", desc.entries.first.snapshot.name
        assert_equal 2, desc.entries.first.siblings.length
      end

      def test_single_returns_true_for_one_entry
        snap = Snapshot.new(name: "snap1", vmid: 100)
        desc = SnapshotDescription.new(entries: [
          SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        assert desc.single?
      end

      def test_single_returns_false_for_multiple_entries
        snap1 = Snapshot.new(name: "snap1", vmid: 100)
        snap2 = Snapshot.new(name: "snap1", vmid: 101)
        desc = SnapshotDescription.new(entries: [
          SnapshotDescription::Entry.new(snapshot: snap1, siblings: [snap1]),
          SnapshotDescription::Entry.new(snapshot: snap2, siblings: [snap2])
        ])

        refute desc.single?
      end
    end
  end
end
