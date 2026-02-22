# frozen_string_literal: true

require "test_helper"

class SelectorsVolumeTest < Minitest::Test
  def test_filter_by_format
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", format: "raw", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", format: "qcow2", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("format=raw")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "scsi0", result[0].name
  end

  def test_filter_by_storage
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", storage: "local-lvm", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", storage: "ceph-pool", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("storage=local-lvm")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "local-lvm", result[0].storage
  end

  def test_filter_by_node
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", node: "pve2")
    ]
    selector = Pvectl::Selectors::Volume.parse("node=pve1")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "pve1", result[0].node
  end

  def test_filter_by_content
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", content: "images", node: "pve1"),
      Pvectl::Models::Volume.new(name: "rootfs", content: "rootdir", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("content=images")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "images", result[0].content
  end

  def test_filter_by_resource_type
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", resource_type: "vm", node: "pve1"),
      Pvectl::Models::Volume.new(name: "rootfs", resource_type: "ct", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("resource_type=vm")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "vm", result[0].resource_type
  end

  def test_filter_by_name
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("name=scsi0")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "scsi0", result[0].name
  end

  def test_empty_selector_returns_all
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", node: "pve1")
    ]
    selector = Pvectl::Selectors::Volume.parse("")
    result = selector.apply(volumes)
    assert_equal 2, result.length
  end

  def test_unsupported_field_raises
    assert_raises(ArgumentError) do
      selector = Pvectl::Selectors::Volume.parse("unknown=val")
      selector.apply([Pvectl::Models::Volume.new(node: "pve1")])
    end
  end

  def test_multiple_conditions
    volumes = [
      Pvectl::Models::Volume.new(name: "scsi0", format: "raw", storage: "local-lvm", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi1", format: "qcow2", storage: "local-lvm", node: "pve1"),
      Pvectl::Models::Volume.new(name: "scsi2", format: "raw", storage: "ceph-pool", node: "pve2")
    ]
    selector = Pvectl::Selectors::Volume.parse("format=raw,storage=local-lvm")
    result = selector.apply(volumes)
    assert_equal 1, result.length
    assert_equal "scsi0", result[0].name
  end
end
