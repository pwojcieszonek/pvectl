# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class SnapshotTest < Minitest::Test
      def setup
        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @repository = Snapshot.new(@mock_connection)
      end

      def test_list_returns_snapshots_for_vm
        api_response = [
          { name: "snap1", snaptime: 1706800000, description: "First", vmstate: 0 },
          { name: "snap2", snaptime: 1706900000, description: "Second", vmstate: 1 },
          { name: "current", description: "current state" }
        ]

        mock_resource = Minitest::Mock.new
        mock_resource.expect(:get, api_response)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot"])

        snapshots = @repository.list(100, "pve1", :qemu)

        assert_equal 2, snapshots.length
        assert_equal "snap1", snapshots[0].name
        assert_equal "snap2", snapshots[1].name
        assert_equal 100, snapshots[0].vmid
        assert_equal "pve1", snapshots[0].node
        assert_equal :qemu, snapshots[0].resource_type

        mock_resource.verify
        @mock_client.verify
      end

      def test_list_returns_snapshots_for_container
        api_response = [
          { name: "snap1", snaptime: 1706800000, description: "LXC snap" },
          { name: "current", description: "current state" }
        ]

        mock_resource = Minitest::Mock.new
        mock_resource.expect(:get, api_response)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/lxc/101/snapshot"])

        snapshots = @repository.list(101, "pve1", :lxc)

        assert_equal 1, snapshots.length
        assert_equal "snap1", snapshots[0].name
        assert_equal :lxc, snapshots[0].resource_type

        mock_resource.verify
        @mock_client.verify
      end

      def test_list_excludes_current_snapshot
        api_response = [
          { name: "real-snap", snaptime: 1706800000 },
          { name: "current", description: "You are here!" }
        ]

        mock_resource = Minitest::Mock.new
        mock_resource.expect(:get, api_response)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot"])

        snapshots = @repository.list(100, "pve1", :qemu)

        assert_equal 1, snapshots.length
        assert_equal "real-snap", snapshots[0].name

        mock_resource.verify
      end

      def test_list_returns_empty_array_on_error
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:get, nil) { raise StandardError, "API error" }
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot"])

        snapshots = @repository.list(100, "pve1", :qemu)

        assert_equal [], snapshots
      end

      # --- create tests ---

      def test_create_snapshot_for_vm
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:post, "UPID:pve1:00001234:...", [{ snapname: "snap1", description: "Test" }])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.create(100, "pve1", :qemu, name: "snap1", description: "Test")

        assert_equal "UPID:pve1:00001234:...", upid
        mock_resource.verify
      end

      def test_create_snapshot_with_vmstate
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:post, "UPID:pve1:00001234:...", [{ snapname: "snap1", vmstate: true }])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.create(100, "pve1", :qemu, name: "snap1", vmstate: true)

        assert_equal "UPID:pve1:00001234:...", upid
        mock_resource.verify
      end

      def test_create_snapshot_for_container_ignores_vmstate
        mock_resource = Minitest::Mock.new
        # vmstate should NOT be sent for LXC containers
        mock_resource.expect(:post, "UPID:pve1:00001235:...", [{ snapname: "snap1" }])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/lxc/101/snapshot"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.create(101, "pve1", :lxc, name: "snap1", vmstate: true)

        assert_equal "UPID:pve1:00001235:...", upid
        mock_resource.verify
      end

      # --- delete tests ---

      def test_delete_snapshot
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:delete, "UPID:pve1:00001236:...", [{}])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot/snap1"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.delete(100, "pve1", :qemu, "snap1")

        assert_equal "UPID:pve1:00001236:...", upid
        mock_resource.verify
      end

      def test_delete_snapshot_with_force
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:delete, "UPID:pve1:00001236:...", [{ force: true }])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot/snap1"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.delete(100, "pve1", :qemu, "snap1", force: true)

        assert_equal "UPID:pve1:00001236:...", upid
        mock_resource.verify
      end

      # --- rollback tests ---

      def test_rollback_snapshot
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:post, "UPID:pve1:00001237:...", [{}])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/qemu/100/snapshot/snap1/rollback"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.rollback(100, "pve1", :qemu, "snap1")

        assert_equal "UPID:pve1:00001237:...", upid
        mock_resource.verify
      end

      def test_rollback_snapshot_with_start
        mock_resource = Minitest::Mock.new
        mock_resource.expect(:post, "UPID:pve1:00001237:...", [{ start: true }])

        @mock_connection = Minitest::Mock.new
        @mock_client = Minitest::Mock.new
        @mock_connection.expect(:client, @mock_client)
        @mock_client.expect(:[], mock_resource, ["nodes/pve1/lxc/101/snapshot/snap1/rollback"])

        @repository = Snapshot.new(@mock_connection)
        upid = @repository.rollback(101, "pve1", :lxc, "snap1", start: true)

        assert_equal "UPID:pve1:00001237:...", upid
        mock_resource.verify
      end
    end
  end
end
