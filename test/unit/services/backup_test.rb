# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class BackupTest < Minitest::Test
      def setup
        @mock_backup_repo = Minitest::Mock.new
        @mock_resolver = Minitest::Mock.new
        @mock_task_repo = Minitest::Mock.new

        @service = Backup.new(
          backup_repo: @mock_backup_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo
        )
      end

      # --- list tests ---

      def test_list_returns_all_backups
        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1"),
          Models::Backup.new(volid: "local:backup/vzdump-qemu-101.vma.zst", vmid: 101, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups, [], vmid: nil, storage: nil)

        result = @service.list

        assert_equal 2, result.length
        assert_equal 100, result[0].vmid
        @mock_backup_repo.verify
      end

      def test_list_with_vmid_filter
        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups, [], vmid: 100, storage: nil)

        result = @service.list(vmid: 100)

        assert_equal 1, result.length
        assert_equal 100, result[0].vmid
        @mock_backup_repo.verify
      end

      def test_list_with_storage_filter
        backups = [
          Models::Backup.new(volid: "nfs:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1", storage: "nfs")
        ]
        @mock_backup_repo.expect(:list, backups, [], vmid: nil, storage: "nfs")

        result = @service.list(storage: "nfs")

        assert_equal 1, result.length
        @mock_backup_repo.verify
      end

      def test_list_returns_empty_when_no_backups
        @mock_backup_repo.expect(:list, [], [], vmid: nil, storage: nil)

        result = @service.list

        assert_equal [], result
        @mock_backup_repo.verify
      end

      # --- create tests ---

      def test_create_returns_success_result
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_backup_repo.expect(:create, "UPID:pve1:00001234:...",
          [100, "pve1"],
          storage: "local", mode: "snapshot", compress: "zstd", notes: nil, protected: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 300)

        results = @service.create([100], storage: "local")

        assert_equal 1, results.length
        assert results[0].successful?
        assert_equal 100, results[0].resource[:vmid]
        @mock_resolver.verify
        @mock_backup_repo.verify
        @mock_task_repo.verify
      end

      def test_create_multiple_returns_results_for_each
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_backup_repo.expect(:create, "UPID:pve1:00001234:...",
          [100, "pve1"],
          storage: "local", mode: "snapshot", compress: "zstd", notes: nil, protected: false)
        @mock_backup_repo.expect(:create, "UPID:pve2:00001235:...",
          [101, "pve2"],
          storage: "local", mode: "snapshot", compress: "zstd", notes: nil, protected: false)

        task1 = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        task2 = Models::Task.new(upid: "UPID:pve2:00001235:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task1, ["UPID:pve1:00001234:..."], timeout: 300)
        @mock_task_repo.expect(:wait, task2, ["UPID:pve2:00001235:..."], timeout: 300)

        results = @service.create([100, 101], storage: "local")

        assert_equal 2, results.length
        assert results.all?(&:successful?)
      end

      def test_create_with_custom_options
        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_backup_repo.expect(:create, "UPID:pve1:00001234:...",
          [100, "pve1"],
          storage: "nfs", mode: "suspend", compress: "gzip", notes: "Daily backup", protected: true)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 300)

        results = @service.create([100], storage: "nfs", mode: "suspend", compress: "gzip",
                                         notes: "Daily backup", protected: true)

        assert_equal 1, results.length
        assert results[0].successful?
        @mock_backup_repo.verify
      end

      def test_create_returns_pending_in_async_mode
        @service = Backup.new(
          backup_repo: @mock_backup_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { async: true }
        )

        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_backup_repo.expect(:create, "UPID:pve1:00001234:...",
          [100, "pve1"],
          storage: "local", mode: "snapshot", compress: "zstd", notes: nil, protected: false)

        results = @service.create([100], storage: "local")

        assert_equal 1, results.length
        assert results[0].pending?
        assert_equal "UPID:pve1:00001234:...", results[0].task_upid
      end

      def test_create_with_fail_fast_stops_on_error
        @service = Backup.new(
          backup_repo: @mock_backup_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { fail_fast: true }
        )

        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" },
          { vmid: 101, node: "pve2", type: :lxc, name: "cache" }
        ], [[100, 101]])

        @mock_backup_repo.expect(:create, nil) { raise StandardError, "API error" }

        results = @service.create([100, 101], storage: "local")

        assert_equal 1, results.length
        assert results[0].failed?
        assert_equal "API error", results[0].error
      end

      def test_create_returns_empty_for_unknown_vmids
        @mock_resolver.expect(:resolve_multiple, [], [[999]])

        results = @service.create([999], storage: "local")

        assert_equal [], results
        @mock_resolver.verify
      end

      # --- delete tests ---

      def test_delete_returns_success_result
        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups)

        @mock_backup_repo.expect(:delete, "UPID:pve1:00001236:...",
          ["local:backup/vzdump-qemu-100.vma.zst", "pve1"])

        task = Models::Task.new(upid: "UPID:pve1:00001236:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001236:..."], timeout: 300)

        result = @service.delete("local:backup/vzdump-qemu-100.vma.zst")

        assert result.successful?
        assert_equal :delete, result.operation
        @mock_backup_repo.verify
      end

      def test_delete_returns_error_for_unknown_backup
        @mock_backup_repo.expect(:list, [])

        result = @service.delete("local:backup/vzdump-qemu-999.vma.zst")

        assert result.failed?
        assert_match(/not found/i, result.error)
        @mock_backup_repo.verify
      end

      # --- restore tests ---

      def test_restore_returns_success_result
        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups)

        @mock_backup_repo.expect(:restore, "UPID:pve1:00001237:...",
          ["local:backup/vzdump-qemu-100.vma.zst", "pve1"],
          vmid: 200, storage: nil, force: false, start: false, unique: false)

        task = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001237:..."], timeout: 300)

        result = @service.restore("local:backup/vzdump-qemu-100.vma.zst", vmid: 200)

        assert result.successful?
        assert_equal :restore, result.operation
        @mock_backup_repo.verify
      end

      def test_restore_with_options
        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups)

        @mock_backup_repo.expect(:restore, "UPID:pve1:00001237:...",
          ["local:backup/vzdump-qemu-100.vma.zst", "pve1"],
          vmid: 200, storage: "local-lvm", force: true, start: true, unique: true)

        task = Models::Task.new(upid: "UPID:pve1:00001237:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001237:..."], timeout: 300)

        result = @service.restore("local:backup/vzdump-qemu-100.vma.zst",
                                  vmid: 200, storage: "local-lvm", force: true, start: true, unique: true)

        assert result.successful?
        @mock_backup_repo.verify
      end

      def test_restore_returns_pending_in_async_mode
        @service = Backup.new(
          backup_repo: @mock_backup_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { async: true }
        )

        backups = [
          Models::Backup.new(volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, node: "pve1")
        ]
        @mock_backup_repo.expect(:list, backups)

        @mock_backup_repo.expect(:restore, "UPID:pve1:00001237:...",
          ["local:backup/vzdump-qemu-100.vma.zst", "pve1"],
          vmid: 200, storage: nil, force: false, start: false, unique: false)

        result = @service.restore("local:backup/vzdump-qemu-100.vma.zst", vmid: 200)

        assert result.pending?
        assert_equal "UPID:pve1:00001237:...", result.task_upid
      end

      def test_restore_returns_error_for_unknown_backup
        @mock_backup_repo.expect(:list, [])

        result = @service.restore("local:backup/vzdump-qemu-999.vma.zst", vmid: 200)

        assert result.failed?
        assert_match(/not found/i, result.error)
        @mock_backup_repo.verify
      end

      # --- timeout tests ---

      def test_uses_custom_timeout
        @service = Backup.new(
          backup_repo: @mock_backup_repo,
          resource_resolver: @mock_resolver,
          task_repo: @mock_task_repo,
          options: { timeout: 600 }
        )

        @mock_resolver.expect(:resolve_multiple, [
          { vmid: 100, node: "pve1", type: :qemu, name: "web" }
        ], [[100]])

        @mock_backup_repo.expect(:create, "UPID:pve1:00001234:...",
          [100, "pve1"],
          storage: "local", mode: "snapshot", compress: "zstd", notes: nil, protected: false)

        task = Models::Task.new(upid: "UPID:pve1:00001234:...", status: "stopped", exitstatus: "OK")
        @mock_task_repo.expect(:wait, task, ["UPID:pve1:00001234:..."], timeout: 600)

        @service.create([100], storage: "local")

        @mock_task_repo.verify
      end
    end
  end
end
