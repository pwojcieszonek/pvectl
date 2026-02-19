# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class SnapshotTest < Minitest::Test
      def test_initializes_with_attributes
        snap = Snapshot.new(
          name: "before-upgrade",
          snaptime: 1706800000,
          description: "Snapshot before upgrade",
          vmstate: 1
        )

        assert_equal "before-upgrade", snap.name
        assert_equal 1706800000, snap.snaptime
        assert_equal "Snapshot before upgrade", snap.description
        assert_equal 1, snap.vmstate
      end

      def test_has_vmstate_predicate
        with_state = Snapshot.new(vmstate: 1)
        without_state = Snapshot.new(vmstate: 0)
        nil_state = Snapshot.new(vmstate: nil)

        assert with_state.has_vmstate?
        refute without_state.has_vmstate?
        refute nil_state.has_vmstate?
      end

      def test_created_at
        snap = Snapshot.new(snaptime: 1706800000)
        assert_instance_of Time, snap.created_at
        assert_equal 1706800000, snap.created_at.to_i
      end

      def test_created_at_nil
        snap = Snapshot.new(snaptime: nil)
        assert_nil snap.created_at
      end

      def test_vmid_attribute
        snapshot = Snapshot.new(name: "snap1", vmid: 100)
        assert_equal 100, snapshot.vmid
      end

      def test_node_attribute
        snapshot = Snapshot.new(name: "snap1", node: "pve1")
        assert_equal "pve1", snapshot.node
      end

      def test_resource_type_attribute
        snapshot = Snapshot.new(name: "snap1", resource_type: :qemu)
        assert_equal :qemu, snapshot.resource_type
      end

      def test_vm_predicate_returns_true_for_qemu
        snapshot = Snapshot.new(name: "snap1", resource_type: :qemu)
        assert snapshot.vm?
        refute snapshot.container?
      end

      def test_container_predicate_returns_true_for_lxc
        snapshot = Snapshot.new(name: "snap1", resource_type: :lxc)
        assert snapshot.container?
        refute snapshot.vm?
      end

      def test_vm_predicate_returns_false_when_nil
        snapshot = Snapshot.new(name: "snap1")
        refute snapshot.vm?
        refute snapshot.container?
      end
    end
  end
end
