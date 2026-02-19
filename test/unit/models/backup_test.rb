# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class BackupTest < Minitest::Test
      def test_initializes_with_attributes
        backup = Backup.new(
          volid: "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst",
          vmid: 100,
          size: 1610612736,
          ctime: 1705315800,
          format: "vma",
          notes: "Pre-upgrade",
          protected: true
        )

        assert_equal "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst", backup.volid
        assert_equal 100, backup.vmid
        assert_equal 1610612736, backup.size
        assert_equal "vma", backup.format
        assert_equal "Pre-upgrade", backup.notes
        assert backup.protected?
      end

      def test_created_at_returns_time
        backup = Backup.new(ctime: 1705315800)
        assert_instance_of Time, backup.created_at
        assert_equal 1705315800, backup.created_at.to_i
      end

      def test_created_at_nil_when_no_ctime
        backup = Backup.new(ctime: nil)
        assert_nil backup.created_at
      end

      def test_vm_predicate_for_qemu
        backup = Backup.new(resource_type: :qemu)
        assert backup.vm?
        refute backup.container?
      end

      def test_container_predicate_for_lxc
        backup = Backup.new(resource_type: :lxc)
        assert backup.container?
        refute backup.vm?
      end

      def test_detects_qemu_type_from_volid
        backup = Backup.new(volid: "local:backup/vzdump-qemu-100-xxx.vma")
        assert_equal :qemu, backup.resource_type
        assert backup.vm?
      end

      def test_detects_lxc_type_from_volid
        backup = Backup.new(volid: "local:backup/vzdump-lxc-101-xxx.tar")
        assert_equal :lxc, backup.resource_type
        assert backup.container?
      end

      def test_extracts_storage_from_volid
        backup = Backup.new(volid: "nfs:backup/vzdump-qemu-100-xxx.vma")
        assert_equal "nfs", backup.storage
      end

      def test_filename_from_volid
        backup = Backup.new(volid: "local:backup/vzdump-qemu-100-2024_01_15.vma.zst")
        assert_equal "vzdump-qemu-100-2024_01_15.vma.zst", backup.filename
      end

      def test_filename_nil_when_no_volid
        backup = Backup.new(volid: nil)
        assert_nil backup.filename
      end

      def test_human_size_gib
        backup = Backup.new(size: 1610612736) # 1.5 GiB
        assert_equal "1.5 GiB", backup.human_size
      end

      def test_human_size_mib
        backup = Backup.new(size: 268435456) # 256 MiB
        assert_equal "256.0 MiB", backup.human_size
      end

      def test_human_size_nil_when_no_size
        backup = Backup.new(size: nil)
        assert_nil backup.human_size
      end

      def test_protected_defaults_to_false
        backup = Backup.new(volid: "local:backup/test.vma")
        refute backup.protected?
      end

      def test_node_attribute
        backup = Backup.new(node: "pve1")
        assert_equal "pve1", backup.node
      end
    end
  end
end
