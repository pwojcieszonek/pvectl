# frozen_string_literal: true

require "test_helper"

class VolumePresenterTest < Minitest::Test
  def setup
    @presenter = Pvectl::Presenters::Volume.new
  end

  def test_columns
    assert_equal %w[NODE RESOURCE ID NAME STORAGE SIZE FORMAT], @presenter.columns
  end

  def test_extra_columns
    assert_equal %w[VOLUME-ID CACHE DISCARD SSD IOTHREAD BACKUP], @presenter.extra_columns
  end

  def test_to_row_from_config
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", size: "32G", format: "raw",
      resource_type: "vm", resource_id: 100, node: "pve1"
    )
    row = @presenter.to_row(vol)
    assert_equal ["pve1", "vm", "100", "scsi0", "local-lvm", "32G", "raw"], row
  end

  def test_to_row_nil_values
    vol = Pvectl::Models::Volume.new(node: "pve1", resource_type: "vm")
    row = @presenter.to_row(vol)
    assert_equal ["pve1", "vm", "-", "-", "-", "-", "-"], row
  end

  def test_extra_values
    vol = Pvectl::Models::Volume.new(
      volume_id: "vm-100-disk-0", cache: "writeback",
      discard: "on", ssd: 1, iothread: 1, backup: 1, node: "pve1"
    )
    extra = @presenter.extra_values(vol)
    assert_equal ["vm-100-disk-0", "writeback", "on", "1", "1", "1"], extra
  end

  def test_extra_values_nil
    vol = Pvectl::Models::Volume.new(node: "pve1")
    extra = @presenter.extra_values(vol)
    assert_equal ["-", "-", "-", "-", "-", "-"], extra
  end

  def test_to_hash
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", volume_id: "vm-100-disk-0",
      size: "32G", format: "raw", resource_type: "vm", resource_id: 100,
      node: "pve1", discard: "on"
    )
    hash = @presenter.to_hash(vol)
    assert_equal "scsi0", hash["name"]
    assert_equal "local-lvm", hash["storage"]
    assert_equal "vm-100-disk-0", hash["volume_id"]
    assert_equal "32G", hash["size"]
    assert_equal "vm", hash["resource_type"]
    assert_equal 100, hash["resource_id"]
    assert_equal "on", hash["discard"]
  end

  def test_to_hash_includes_all_attributes
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", volume_id: "vm-100-disk-0",
      volid: "local-lvm:vm-100-disk-0", size: "32G", format: "raw",
      resource_type: "vm", resource_id: 100, node: "pve1",
      content: "images", cache: "writeback", discard: "on",
      ssd: 1, iothread: 1, backup: 1, mp: "/mnt/data"
    )
    hash = @presenter.to_hash(vol)
    expected_keys = %w[name storage volume_id volid size format resource_type
                       resource_id node content cache discard ssd iothread backup mp]
    expected_keys.each do |key|
      assert_includes hash.keys, key, "Expected hash to include key '#{key}'"
    end
  end

  def test_to_description
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", volume_id: "vm-100-disk-0",
      volid: "local-lvm:vm-100-disk-0", size: "32G", format: "raw",
      resource_type: "vm", resource_id: 100, node: "pve1",
      discard: "on", ssd: 1, iothread: 1
    )
    desc = @presenter.to_description(vol)
    assert_includes desc.keys, "Volume Info"
    info = desc["Volume Info"]
    assert_equal "scsi0", info["Name"]
    assert_equal "local-lvm", info["Storage"]
    assert_equal "32G", info["Size"]
  end

  def test_to_description_excludes_nil_optional_fields
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", size: "32G", format: "raw",
      resource_type: "vm", resource_id: 100, node: "pve1"
    )
    desc = @presenter.to_description(vol)
    info = desc["Volume Info"]
    refute_includes info.keys, "Content"
    refute_includes info.keys, "Cache"
    refute_includes info.keys, "Discard"
    refute_includes info.keys, "SSD"
    refute_includes info.keys, "IO Thread"
    refute_includes info.keys, "Backup"
    refute_includes info.keys, "Mount Point"
  end

  def test_to_description_includes_present_optional_fields
    vol = Pvectl::Models::Volume.new(
      name: "scsi0", storage: "local-lvm", size: "32G", format: "raw",
      resource_type: "vm", resource_id: 100, node: "pve1",
      cache: "writeback", discard: "on", ssd: 1, backup: 0, mp: "/mnt/data"
    )
    desc = @presenter.to_description(vol)
    info = desc["Volume Info"]
    assert_equal "writeback", info["Cache"]
    assert_equal "on", info["Discard"]
    assert_equal 1, info["SSD"]
    assert_equal 0, info["Backup"]
    assert_equal "/mnt/data", info["Mount Point"]
  end
end
