# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Presenters
    class BackupPresenterTest < Minitest::Test
      def setup
        @presenter = Backup.new
      end

      def test_columns
        expected = %w[VMID TYPE CREATED SIZE STORAGE PROTECTED]
        assert_equal expected, @presenter.columns
      end

      def test_extra_columns
        expected = %w[FORMAT NOTES VOLID]
        assert_equal expected, @presenter.extra_columns
      end

      def test_wide_columns
        expected = %w[VMID TYPE CREATED SIZE STORAGE PROTECTED FORMAT NOTES VOLID]
        assert_equal expected, @presenter.wide_columns
      end

      def test_to_row_for_qemu_backup
        backup = Models::Backup.new(
          volid: "local:backup/vzdump-qemu-100-2024_01_15.vma.zst",
          vmid: 100,
          storage: "local",
          resource_type: :qemu,
          size: 1610612736,
          ctime: 1705315800,
          protected: true
        )

        row = @presenter.to_row(backup)

        assert_equal 100, row[0]           # VMID
        assert_equal "qemu", row[1]        # TYPE
        assert_match(/2024/, row[2])       # CREATED
        assert_equal "1.5 GiB", row[3]     # SIZE
        assert_equal "local", row[4]       # STORAGE
        assert_equal "yes", row[5]         # PROTECTED
      end

      def test_to_row_for_lxc_backup
        backup = Models::Backup.new(
          volid: "local:backup/vzdump-lxc-101-xxx.tar",
          vmid: 101,
          resource_type: :lxc,
          protected: false
        )

        row = @presenter.to_row(backup)

        assert_equal "lxc", row[1]
        assert_equal "no", row[5]
      end

      def test_to_row_handles_nil_values
        backup = Models::Backup.new(
          volid: "local:backup/vzdump-qemu-100.vma"
        )

        row = @presenter.to_row(backup)

        assert_equal "-", row[2]  # CREATED nil
        assert_nil row[3]         # SIZE nil
      end

      def test_to_row_handles_unknown_type
        backup = Models::Backup.new(
          volid: "local:backup/unknown.vma",
          resource_type: nil
        )

        row = @presenter.to_row(backup)

        assert_equal "-", row[1]  # TYPE unknown
      end

      def test_extra_values
        backup = Models::Backup.new(
          volid: "local:backup/vzdump-qemu-100.vma",
          format: "vma",
          notes: "Test backup"
        )

        extra = @presenter.extra_values(backup)

        assert_equal "vma", extra[0]
        assert_equal "Test backup", extra[1]
        assert_equal "local:backup/vzdump-qemu-100.vma", extra[2]
      end

      def test_to_hash
        backup = Models::Backup.new(
          volid: "local:backup/vzdump-qemu-100.vma",
          vmid: 100,
          node: "pve1",
          storage: "local",
          resource_type: :qemu,
          size: 1000000,
          ctime: 1705315800,
          format: "vma",
          notes: "Test",
          protected: true
        )

        hash = @presenter.to_hash(backup)

        assert_equal 100, hash["vmid"]
        assert_equal "qemu", hash["type"]
        assert_equal "local", hash["storage"]
        assert_equal "pve1", hash["node"]
        assert hash["protected"]
        assert_equal "local:backup/vzdump-qemu-100.vma", hash["volid"]
        assert_match(/2024-01-15/, hash["created_at"])
      end

      def test_truncate_long_notes
        backup = Models::Backup.new(
          notes: "This is a very long note that should be truncated for display"
        )

        extra = @presenter.extra_values(backup)
        assert extra[1].length <= 30
        assert extra[1].end_with?("...")
      end

      def test_truncate_nil_notes
        backup = Models::Backup.new(notes: nil)

        extra = @presenter.extra_values(backup)
        assert_nil extra[1]
      end

      def test_truncate_short_notes
        backup = Models::Backup.new(notes: "Short note")

        extra = @presenter.extra_values(backup)
        assert_equal "Short note", extra[1]
      end
    end
  end
end
