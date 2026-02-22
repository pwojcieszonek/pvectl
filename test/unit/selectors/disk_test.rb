# frozen_string_literal: true

require "test_helper"

class SelectorsDiskTest < Minitest::Test
  def setup
    @ssd1 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sda", type: "ssd", health: "PASSED",
      used: "LVM", node: "pve1", gpt: 1, mounted: 1
    )
    @hdd1 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sdb", type: "hdd", health: "PASSED",
      used: "ZFS", node: "pve1", gpt: 1, mounted: 1
    )
    @ssd2 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/nvme0n1", type: "ssd", health: "PASSED",
      used: "ext4", node: "pve2", gpt: 1, mounted: 1
    )
    @failed_disk = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sdc", type: "hdd", health: "FAILED",
      used: nil, node: "pve2", gpt: 0, mounted: 0
    )
    @all_disks = [@ssd1, @hdd1, @ssd2, @failed_disk]
  end

  # Class structure
  def test_class_exists
    assert_kind_of Class, Pvectl::Selectors::Disk
  end

  def test_inherits_from_base
    assert Pvectl::Selectors::Disk < Pvectl::Selectors::Base
  end

  def test_supported_fields
    assert_equal %w[type health used node gpt mounted], Pvectl::Selectors::Disk::SUPPORTED_FIELDS
  end

  # Type filtering
  def test_filter_by_type_ssd
    selector = Pvectl::Selectors::Disk.parse("type=ssd")
    result = selector.apply(@all_disks)
    assert_equal 2, result.size
    assert result.all?(&:ssd?)
  end

  def test_filter_by_type_hdd
    selector = Pvectl::Selectors::Disk.parse("type=hdd")
    result = selector.apply(@all_disks)
    assert_equal 2, result.size
  end

  # Health filtering
  def test_filter_by_health_passed
    selector = Pvectl::Selectors::Disk.parse("health=PASSED")
    result = selector.apply(@all_disks)
    assert_equal 3, result.size
  end

  def test_filter_by_health_failed
    selector = Pvectl::Selectors::Disk.parse("health=FAILED")
    result = selector.apply(@all_disks)
    assert_equal 1, result.size
    assert_equal "/dev/sdc", result.first.devpath
  end

  # Used filtering
  def test_filter_by_used
    selector = Pvectl::Selectors::Disk.parse("used=LVM")
    result = selector.apply(@all_disks)
    assert_equal 1, result.size
    assert_equal "/dev/sda", result.first.devpath
  end

  # Node filtering
  def test_filter_by_node
    selector = Pvectl::Selectors::Disk.parse("node=pve1")
    result = selector.apply(@all_disks)
    assert_equal 2, result.size
    assert result.all? { |d| d.node == "pve1" }
  end

  # GPT filtering
  def test_filter_by_gpt
    selector = Pvectl::Selectors::Disk.parse("gpt=yes")
    result = selector.apply(@all_disks)
    assert_equal 3, result.size
  end

  def test_filter_by_gpt_no
    selector = Pvectl::Selectors::Disk.parse("gpt=no")
    result = selector.apply(@all_disks)
    assert_equal 1, result.size
    assert_equal "/dev/sdc", result.first.devpath
  end

  # Mounted filtering
  def test_filter_by_mounted
    selector = Pvectl::Selectors::Disk.parse("mounted=yes")
    result = selector.apply(@all_disks)
    assert_equal 3, result.size
  end

  # Multiple conditions
  def test_filter_multiple_conditions
    selector = Pvectl::Selectors::Disk.parse("type=ssd,node=pve1")
    result = selector.apply(@all_disks)
    assert_equal 1, result.size
    assert_equal "/dev/sda", result.first.devpath
  end

  # Empty selector
  def test_empty_selector_returns_all
    selector = Pvectl::Selectors::Disk.parse("")
    result = selector.apply(@all_disks)
    assert_equal 4, result.size
  end

  # Unknown field
  def test_unknown_field_raises_error
    selector = Pvectl::Selectors::Disk.parse("unknown=value")
    assert_raises(ArgumentError) do
      selector.apply(@all_disks)
    end
  end
end
