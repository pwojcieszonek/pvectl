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

          # ---------------------------
          # Standard interface tests (node:, name:, args:)
          # ---------------------------

          def test_list_accepts_standard_handler_interface
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]])

            # Should accept standard interface with args containing VMIDs
            result = @handler.list(node: nil, name: nil, args: ["100"])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_list_with_args_containing_vmids
            snapshots = [
              Models::Snapshot.new(name: "snap1", vmid: 100),
              Models::Snapshot.new(name: "snap2", vmid: 100)
            ]
            @mock_service.expect(:list, snapshots, [[100]])

            result = @handler.list(node: nil, name: nil, args: ["100"])

            assert_equal 2, result.length
            assert_equal "snap1", result[0].name
            @mock_service.verify
          end

          def test_list_with_multiple_vmids_in_args
            snapshots = [
              Models::Snapshot.new(name: "snap1", vmid: 100),
              Models::Snapshot.new(name: "snap2", vmid: 101)
            ]
            @mock_service.expect(:list, snapshots, [[100, 101]])

            result = @handler.list(node: nil, name: nil, args: ["100", "101"])

            assert_equal 2, result.length
            @mock_service.verify
          end

          def test_list_ignores_node_and_name_parameters
            # For snapshots, node: and name: are ignored - only args matters
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100]])

            result = @handler.list(node: "pve1", name: "ignored", args: ["100"])

            assert_equal 1, result.length
            @mock_service.verify
          end

          def test_presenter_returns_snapshot_presenter
            presenter = @handler.presenter

            assert_instance_of Presenters::Snapshot, presenter
          end

          def test_requires_vmids_in_args
            assert_raises(ArgumentError) do
              @handler.list(node: nil, name: nil, args: [])
            end
          end

          def test_error_message_when_no_vmids
            error = assert_raises(ArgumentError) do
              @handler.list(node: nil, name: nil, args: [])
            end
            assert_equal "At least one VMID is required", error.message
          end

          def test_converts_string_vmids_to_integers
            snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
            @mock_service.expect(:list, snapshots, [[100, 101, 102]])

            @handler.list(node: nil, name: nil, args: ["100", "101", "102"])

            @mock_service.verify
          end
        end
      end
    end
  end
end
