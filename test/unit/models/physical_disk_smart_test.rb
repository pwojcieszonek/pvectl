# frozen_string_literal: true

require "test_helper"

class PhysicalDiskSmartTest < Minitest::Test
  def setup
    @disk = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/nvme0n1", model: "Samsung SSD 970", size: 1_000_204_886_016,
      type: "nvme", health: "PASSED", node: "pve1"
    )
  end

  # ---------------------------
  # Default SMART values
  # ---------------------------

  def test_smart_type_is_nil_by_default
    assert_nil @disk.smart_type
  end

  def test_smart_attributes_is_nil_by_default
    assert_nil @disk.smart_attributes
  end

  def test_smart_text_is_nil_by_default
    assert_nil @disk.smart_text
  end

  def test_wearout_is_nil_by_default
    assert_nil @disk.wearout
  end

  # ---------------------------
  # merge_smart
  # ---------------------------

  def test_merge_smart_sets_smart_type
    @disk.merge_smart({ type: "text", health: "PASSED", text: "foo", attributes: nil })

    assert_equal "text", @disk.smart_type
  end

  def test_merge_smart_sets_smart_text
    @disk.merge_smart({ type: "text", health: "PASSED", text: "Temperature: 34 C" })

    assert_equal "Temperature: 34 C", @disk.smart_text
  end

  def test_merge_smart_sets_smart_attributes
    attrs = [{ id: 1, name: "Raw_Read_Error_Rate", value: 200, worst: 200, threshold: 51, raw: "0" }]
    @disk.merge_smart({ type: "ata", health: "PASSED", attributes: attrs })

    assert_equal attrs, @disk.smart_attributes
  end

  def test_merge_smart_sets_wearout
    @disk.merge_smart({ type: "text", health: "PASSED", wearout: 2 })

    assert_equal 2, @disk.wearout
  end

  def test_merge_smart_updates_health
    disk = Pvectl::Models::PhysicalDisk.new(devpath: "/dev/sda", health: nil, node: "pve1")

    disk.merge_smart({ type: "ata", health: "PASSED" })

    assert_equal "PASSED", disk.health
  end

  def test_merge_smart_preserves_health_when_smart_data_has_nil_health
    @disk.merge_smart({ type: "text", health: nil })

    assert_equal "PASSED", @disk.health
  end

  def test_merge_smart_preserves_health_when_key_absent
    @disk.merge_smart({ type: "text" })

    assert_equal "PASSED", @disk.health
  end

  def test_merge_smart_with_empty_hash_is_safe
    @disk.merge_smart({})

    assert_nil @disk.smart_type
    assert_nil @disk.smart_text
    assert_equal "PASSED", @disk.health
  end
end
