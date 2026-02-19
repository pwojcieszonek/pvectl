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
    end
  end
end
