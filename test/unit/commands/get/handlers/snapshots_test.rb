# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Get
      module Handlers
        class SnapshotsTest < Minitest::Test
          def setup
            @mock_service = Minitest::Mock.new
            @handler = Snapshots.new(service: @mock_service)
          end

          # --- list tests ---

          def test_list_with_vmid_option
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]], node: nil)

            result = @handler.list(args: [], vmid: ["100"])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_with_multiple_vmids
            snapshots = [
              Models::Snapshot.new(name: "snap1", vmid: 100),
              Models::Snapshot.new(name: "snap2", vmid: 101)
            ]
            @mock_service.expect(:list, snapshots, [[100, 101]], node: nil)

            result = @handler.list(args: [], vmid: ["100", "101"])

            assert_equal 2, result.length
            @mock_service.verify
          end

          def test_list_with_node_filter
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]], node: "pve1")

            result = @handler.list(args: [], vmid: ["100"], node: "pve1")

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_cluster_wide_without_vmid
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[]], node: nil)

            result = @handler.list(args: [])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_cluster_wide_with_node_filter
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[]], node: "pve1")

            result = @handler.list(args: [], node: "pve1")

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_presenter_returns_snapshot_presenter
            presenter = @handler.presenter

            assert_instance_of Presenters::Snapshot, presenter
          end

          # --- describe tests ---

          def test_describe_with_vmid_option
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[100], "snap1"], node: nil)

            result = @handler.describe(name: "snap1", args: [], vmid: ["100"])

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end

          def test_describe_cluster_wide_without_vmid
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[], "snap1"], node: nil)

            result = @handler.describe(name: "snap1", args: [])

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end

          def test_describe_with_node_filter
            description = Models::SnapshotDescription.new(entries: [
              Models::SnapshotDescription::Entry.new(
                snapshot: Models::Snapshot.new(name: "snap1", vmid: 100),
                siblings: [Models::Snapshot.new(name: "snap1", vmid: 100)]
              )
            ])
            @mock_service.expect(:describe, description, [[100], "snap1"], node: "pve1")

            result = @handler.describe(name: "snap1", args: [], vmid: ["100"], node: "pve1")

            assert_instance_of Models::SnapshotDescription, result
            @mock_service.verify
          end
        end
      end
    end
  end
end
