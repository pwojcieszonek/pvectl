# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SnapshotTest < Minitest::Test
      def setup
        @mock_snapshot_repo = Minitest::Mock.new
        @mock_resolver = Minitest::Mock.new
        @mock_task_repo = Minitest::Mock.new

        @service = Snapshot.new(
          snapshot_repo: @mock_snapshot_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo
        )
      end

      def test_list_returns_snapshots_for_single_vmid
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        snapshots = [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu),
          Models::Snapshot.new(name: "snap2", vmid: 100, node: "pve1", resource_type: :qemu)
        ]
        @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

        result = @service.list([100])

        assert_equal 2, result.length
        assert_equal "snap1", result[0].name
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_list_returns_snapshots_for_multiple_vmids
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap2", vmid: 101)
        ], [101, "pve2", :lxc])

        result = @service.list([100, 101])

        assert_equal 2, result.length
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_list_returns_empty_for_unknown_vmid
        @mock_resolver.expect(:resolve_multiple, [], [[999]])

        result = @service.list([999])

        assert_equal [], result
        @mock_resolver.verify
      end

      def test_list_searches_all_resources_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap2", vmid: 101, node: "pve2", resource_type: :lxc)
        ], [101, "pve2", :lxc])

        result = @service.list([])

        assert_equal 2, result.length
        assert_equal "snap1", result[0].name
        assert_equal "snap2", result[1].name
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_list_returns_empty_when_no_resources_in_cluster
        @mock_resolver.expect(:resolve_all, [])

        result = @service.list([])

        assert_equal [], result
        @mock_resolver.verify
      end

      # --- create tests ---

      def test_create_searches_all_resources_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

        results = @service.create([], name: "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      def test_create_returns_success_result
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

        results = @service.create([100], name: "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        assert_equal 100, results[0].resource[:vmid]
        @mock_resolver.verify
        @mock_snapshot_repo.verify
        @mock_task_repo.verify
      end

      def test_create_multiple_returns_results_for_each
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)
        @mock_snapshot_repo.expect(:create, "UPID:pve2:00001235:...", [101, "pve2", :lxc], name: "snap1", description: nil, vmstate: false)

        task1 = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        task2 = Models::Task.new(upid: "UPID:pve2:00001235:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task1, ["UPID:pve1:00001234:..."], timeout: 60)
        @mock_task_repo.expect(:wait, task2, ["UPID:pve2:00001235:..."], timeout: 60)

        results = @service.create([100, 101], name: "snap1")

        assert_equal 2, results.length
        assert results.all?(&:successful?)
      end

      def test_create_returns_pending_in_async_mode
        @service = Snapshot.new(
          snapshot_repo: @mock_snapshot_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { async: true }
        )

        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

        results = @service.create([100], name: "snap1")

        assert_equal 1, results.length
        assert results[0].pending?
        assert_equal "UPID:pve1:00001234:...", results[0].task_upid
      end

      def test_create_with_fail_fast_stops_on_error
        @service = Snapshot.new(
          snapshot_repo: @mock_snapshot_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { fail_fast: true }
        )

        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:create, nil) { raise StandardError, "API error" }

        results = @service.create([100, 101], name: "snap1")

        assert_equal 1, results.length
        assert results[0].failed?
        assert_equal "API error", results[0].error
      end

      # --- delete tests ---

      def test_delete_searches_all_resources_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete([], "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      def test_delete_returns_success_result
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete([100], "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_delete_with_force_passes_flag
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: true)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete([100], "snap1", force: true)

        assert_equal 1, results.length
        @mock_snapshot_repo.verify
      end

      # --- rollback tests ---

      def test_rollback_returns_success_result
        @mock_resolver.expect(:resolve, { vmid: 100, node: "pve1", type: :qemu, name: "web" }, [100])

        @mock_snapshot_repo.expect(:rollback, "UPID:pve1:00001237:...", [100, "pve1", :qemu, "snap1"], start: false)

        task = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001237:..."], timeout: 60)

        result = @service.rollback(100, "snap1")

        assert result.successful?
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_rollback_with_start_passes_flag
        @mock_resolver.expect(:resolve, { vmid: 100, node: "pve1", type: :lxc, name: "cache" }, [100])

        @mock_snapshot_repo.expect(:rollback, "UPID:pve1:00001237:...", [100, "pve1", :lxc, "snap1"], start: true)

        task = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001237:..."], timeout: 60)

        result = @service.rollback(100, "snap1", start: true)

        assert result.successful?
        @mock_snapshot_repo.verify
      end

      def test_rollback_returns_error_for_unknown_vmid
        @mock_resolver.expect(:resolve, nil, [999])

        result = @service.rollback(999, "snap1")

        assert result.failed?
        assert_match(/not found/i, result.error)
        @mock_resolver.verify
      end

      # --- node filtering tests ---

      def test_list_filters_by_node
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)]
        @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

        result = @service.list([100, 101], node: "pve1")

        assert_equal 1, result.length
        assert_equal "snap1", result[0].name
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_list_cluster_wide_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        snapshots = [Models::Snapshot.new(name: "snap1", vmid: 100)]
        @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

        result = @service.list([])

        assert_equal 1, result.length
        @mock_resolver.verify
      end

      def test_create_filters_by_node
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

        results = @service.create([100, 101], name: "snap1", node: "pve1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      def test_delete_filters_by_node
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete([100, 101], "snap1", node: "pve1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      def test_describe_filters_by_node
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        result = @service.describe([100, 101], "snap1", node: "pve1")

        assert result.single?
        assert_equal 100, result.entries.first.snapshot.vmid
        @mock_resolver.verify
      end

      def test_create_cluster_wide_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:create, "UPID:pve1:00001234:...", [100, "pve1", :qemu], name: "snap1", description: nil, vmstate: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 60)

        results = @service.create([], name: "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      def test_delete_cluster_wide_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete([], "snap1")

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_resolver.verify
      end

      # --- delete_all tests ---

      def test_delete_all_deletes_every_snapshot_from_vm
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu),
          Models::Snapshot.new(name: "snap2", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)
        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001237:...", [100, "pve1", :qemu, "snap2"], force: false)

        task1 = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        task2 = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task1, ["UPID:pve1:00001236:..."], timeout: 60)
        @mock_task_repo.expect(:wait, task2, ["UPID:pve1:00001237:..."], timeout: 60)

        results = @service.delete_all([100])

        assert_equal 2, results.length
        assert results.all?(&:successful?)
        @mock_resolver.verify
        @mock_snapshot_repo.verify
        @mock_task_repo.verify
      end

      def test_delete_all_skips_current_pseudo_snapshot
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "current", vmid: 100, node: "pve1", resource_type: :qemu),
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete_all([100])

        assert_equal 1, results.length
        @mock_snapshot_repo.verify
      end

      def test_delete_all_filters_by_node
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete_all([100, 101], node: "pve1")

        assert_equal 1, results.length
        @mock_resolver.verify
      end

      def test_delete_all_cluster_wide_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: false)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete_all([])

        assert_equal 1, results.length
        @mock_resolver.verify
      end

      def test_delete_all_returns_success_when_no_snapshots
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:list, [], [100, "pve1", :qemu])

        results = @service.delete_all([100])

        assert_equal 1, results.length
        assert results[0].successful?
      end

      def test_delete_all_with_force_flag
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "snap1", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:delete, "UPID:pve1:00001236:...", [100, "pve1", :qemu, "snap1"], force: true)

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 60)

        results = @service.delete_all([100], force: true)

        assert_equal 1, results.length
        @mock_snapshot_repo.verify
      end

      # --- describe tests ---

      def test_describe_finds_snapshot_by_name_on_specific_vmid
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        snapshots = [
          Models::Snapshot.new(name: "before-upgrade", vmid: 100, node: "pve1", resource_type: :qemu, snaptime: 1706800000, parent: nil),
          Models::Snapshot.new(name: "after-upgrade", vmid: 100, node: "pve1", resource_type: :qemu, snaptime: 1706900000, parent: "before-upgrade")
        ]
        @mock_snapshot_repo.expect(:list, snapshots, [100, "pve1", :qemu])

        result = @service.describe([100], "before-upgrade")

        assert_instance_of Models::SnapshotDescription, result
        assert result.single?
        assert_equal "before-upgrade", result.entries.first.snapshot.name
        assert_equal 2, result.entries.first.siblings.length
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_describe_finds_snapshot_across_multiple_vmids
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "before-upgrade", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "before-upgrade", vmid: 101, node: "pve2", resource_type: :lxc),
          Models::Snapshot.new(name: "other-snap", vmid: 101, node: "pve2", resource_type: :lxc)
        ], [101, "pve2", :lxc])

        result = @service.describe([100, 101], "before-upgrade")

        refute result.single?
        assert_equal 2, result.entries.length
        assert_equal 100, result.entries[0].snapshot.vmid
        assert_equal 101, result.entries[1].snapshot.vmid
        @mock_resolver.verify
        @mock_snapshot_repo.verify
      end

      def test_describe_raises_not_found_when_snapshot_missing
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "other-snap", vmid: 100)
        ], [100, "pve1", :qemu])

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.describe([100], "nonexistent")
        end
      end

      def test_describe_raises_not_found_when_no_resources_resolved
        @mock_resolver.expect(:resolve_multiple, [], [[999]])

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.describe([999], "snap1")
        end
      end

      def test_describe_searches_all_resources_when_vmids_empty
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "target", vmid: 100, node: "pve1", resource_type: :qemu)
        ], [100, "pve1", :qemu])

        @mock_snapshot_repo.expect(:list, [], [101, "pve2", :lxc])

        result = @service.describe([], "target")

        assert result.single?
        assert_equal 100, result.entries.first.snapshot.vmid
      end

      def test_describe_raises_not_found_when_cluster_scan_finds_nothing
        @mock_resolver.expect(:resolve_all, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ])

        @mock_snapshot_repo.expect(:list, [
          Models::Snapshot.new(name: "other", vmid: 100)
        ], [100, "pve1", :qemu])

        assert_raises(Pvectl::ResourceNotFoundError) do
          @service.describe([], "nonexistent")
        end
      end
    end
  end
end
