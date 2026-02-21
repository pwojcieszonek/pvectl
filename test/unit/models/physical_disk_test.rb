# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class PhysicalDiskTest < Minitest::Test
      def test_initializes_with_attributes
        disk = PhysicalDisk.new(
          devpath: "/dev/sda",
          model: "Samsung SSD 970",
          size: 500_000_000_000,
          type: "ssd",
          health: "PASSED"
        )

        assert_equal "/dev/sda", disk.devpath
        assert_equal "Samsung SSD 970", disk.model
        assert_equal 500_000_000_000, disk.size
        assert_equal "ssd", disk.type
        assert_equal "PASSED", disk.health
      end

      def test_size_gb
        disk = PhysicalDisk.new(size: 500_000_000_000)
        assert_in_delta 465.7, disk.size_gb, 0.1
      end

      def test_size_gb_nil
        disk = PhysicalDisk.new(size: nil)
        assert_nil disk.size_gb
      end

      def test_healthy_predicate
        healthy = PhysicalDisk.new(health: "PASSED")
        unhealthy = PhysicalDisk.new(health: "FAILED")
        unknown = PhysicalDisk.new(health: nil)

        assert healthy.healthy?
        refute unhealthy.healthy?
        refute unknown.healthy?
      end

      def test_ssd_predicate
        ssd = PhysicalDisk.new(type: "ssd")
        hdd = PhysicalDisk.new(type: "hdd")

        assert ssd.ssd?
        refute hdd.ssd?
      end

      def test_initializes_with_new_fields
        disk = PhysicalDisk.new(
          devpath: "/dev/sda",
          model: "Samsung SSD 970",
          size: 500_000_000_000,
          type: "ssd",
          health: "PASSED",
          serial: "S1MZBD0K123",
          vendor: "Samsung",
          node: "pve1",
          gpt: 1,
          mounted: 1,
          used: "LVM",
          wwn: "0x5000c5009abc1234",
          osdid: -1,
          parent: nil
        )

        assert_equal "pve1", disk.node
        assert_equal 1, disk.gpt
        assert_equal 1, disk.mounted
        assert_equal "LVM", disk.used
        assert_equal "0x5000c5009abc1234", disk.wwn
        assert_equal(-1, disk.osdid)
        assert_nil disk.parent
      end

      def test_gpt_predicate
        gpt_disk = PhysicalDisk.new(gpt: 1)
        no_gpt_disk = PhysicalDisk.new(gpt: 0)

        assert gpt_disk.gpt?
        refute no_gpt_disk.gpt?
      end

      def test_mounted_predicate
        mounted = PhysicalDisk.new(mounted: 1)
        not_mounted = PhysicalDisk.new(mounted: 0)

        assert mounted.mounted?
        refute not_mounted.mounted?
      end

      def test_osd_predicate
        osd_disk = PhysicalDisk.new(osdid: 3)
        non_osd = PhysicalDisk.new(osdid: -1)
        nil_osd = PhysicalDisk.new(osdid: nil)

        assert osd_disk.osd?
        refute non_osd.osd?
        refute nil_osd.osd?
      end
    end
  end
end
