# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class SnapshotDescribeTest < Minitest::Test
      def setup
        @presenter = Snapshot.new
      end

      # --- Single VM describe ---

      def test_single_entry_returns_flat_hash
        snap = Models::Snapshot.new(
          name: "before-upgrade", vmid: 100, node: "pve1",
          resource_type: :qemu, snaptime: 1706800000,
          description: "Before upgrade", vmstate: 1, parent: nil
        )
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        result = @presenter.to_description(desc)

        assert_equal "before-upgrade", result["Name"]
        assert_equal 100, result["VMID"]
        assert_equal "pve1", result["Node"]
        assert_equal "qemu", result["Type"]
        assert_equal "Yes", result["VM State"]
        assert_equal "Before upgrade", result["Description"]
      end

      def test_single_entry_includes_snapshot_tree
        parent = Models::Snapshot.new(name: "initial", vmid: 100, parent: nil)
        target = Models::Snapshot.new(name: "before-upgrade", vmid: 100, parent: "initial")
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: target, siblings: [parent, target])
        ])

        result = @presenter.to_description(desc)

        assert result.key?("Snapshot Tree")
        tree = result["Snapshot Tree"]
        assert_includes tree, "initial"
        assert_includes tree, "before-upgrade"
        assert_includes tree, "\u25c0"
      end

      def test_tree_shows_current_as_terminus
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, parent: nil)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        result = @presenter.to_description(desc)
        tree = result["Snapshot Tree"]

        assert_includes tree, "(current)"
      end

      def test_tree_marks_target_with_arrow
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, parent: nil)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        result = @presenter.to_description(desc)
        tree = result["Snapshot Tree"]

        assert_match(/snap1\s+\u25c0/, tree)
      end

      # --- Multiple VM describe ---

      def test_multiple_entries_returns_nested_hash
        snap1 = Models::Snapshot.new(name: "snap", vmid: 100, node: "pve1", resource_type: :qemu)
        snap2 = Models::Snapshot.new(name: "snap", vmid: 201, node: "pve2", resource_type: :lxc)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap1, siblings: [snap1]),
          Models::SnapshotDescription::Entry.new(snapshot: snap2, siblings: [snap2])
        ])

        result = @presenter.to_description(desc)

        assert result.key?("VM 100 (pve1)")
        assert result.key?("CT 201 (pve2)")
      end

      def test_multiple_entries_each_section_has_metadata
        snap1 = Models::Snapshot.new(name: "snap", vmid: 100, node: "pve1", resource_type: :qemu, snaptime: 1706800000)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap1, siblings: [snap1]),
          Models::SnapshotDescription::Entry.new(
            snapshot: Models::Snapshot.new(name: "snap", vmid: 201, node: "pve2", resource_type: :lxc),
            siblings: [Models::Snapshot.new(name: "snap", vmid: 201)]
          )
        ])

        result = @presenter.to_description(desc)

        section = result["VM 100 (pve1)"]
        assert_equal "snap", section["Name"]
        assert_equal 100, section["VMID"]
      end

      # --- Tree building edge cases ---

      def test_tree_with_deep_nesting
        root = Models::Snapshot.new(name: "root", vmid: 100, parent: nil)
        child = Models::Snapshot.new(name: "child", vmid: 100, parent: "root")
        grandchild = Models::Snapshot.new(name: "grandchild", vmid: 100, parent: "child")

        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: grandchild, siblings: [root, child, grandchild])
        ])

        result = @presenter.to_description(desc)
        tree = result["Snapshot Tree"]

        assert_includes tree, "root"
        assert_includes tree, "child"
        assert_includes tree, "grandchild"
        assert_match(/grandchild\s+\u25c0/, tree)
      end

      def test_tree_with_branching
        root = Models::Snapshot.new(name: "root", vmid: 100, parent: nil)
        branch_a = Models::Snapshot.new(name: "branch-a", vmid: 100, parent: "root")
        branch_b = Models::Snapshot.new(name: "branch-b", vmid: 100, parent: "root")

        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: branch_a, siblings: [root, branch_a, branch_b])
        ])

        result = @presenter.to_description(desc)
        tree = result["Snapshot Tree"]

        assert_includes tree, "root"
        assert_includes tree, "branch-a"
        assert_includes tree, "branch-b"
      end

      def test_no_description_shows_dash
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu, description: nil)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        result = @presenter.to_description(desc)

        assert_equal "-", result["Description"]
      end

      # --- JSON/YAML output (to_hash) ---

      def test_to_hash_for_snapshot_description_single
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu, snaptime: 1706800000, parent: nil)
        desc = Models::SnapshotDescription.new(entries: [
          Models::SnapshotDescription::Entry.new(snapshot: snap, siblings: [snap])
        ])

        result = @presenter.to_hash(desc)

        assert_equal "snap1", result["name"]
        assert_equal 100, result["vmid"]
        assert result.key?("snapshot_tree")
        assert_kind_of Array, result["snapshot_tree"]
      end

      # --- Backward compatibility: plain Snapshot model ---

      def test_to_description_with_plain_snapshot_returns_hash
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        result = @presenter.to_description(snap)

        # Should return same as to_hash for plain Snapshot (backward compat)
        assert_equal "snap1", result["name"]
        assert_equal 100, result["vmid"]
      end

      def test_to_hash_with_plain_snapshot_returns_hash
        snap = Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        result = @presenter.to_hash(snap)

        assert_equal "snap1", result["name"]
        assert_equal 100, result["vmid"]
        refute result.key?("snapshot_tree")
      end
    end
  end
end
