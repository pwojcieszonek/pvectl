# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Disk Tests
# =============================================================================

class PresentersDiskTest < Minitest::Test
  def setup
    @ssd_disk = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sda",
      model: "Samsung SSD 970 EVO Plus",
      size: 500_107_862_016,
      type: "ssd",
      health: "PASSED",
      serial: "S4EWNX0M123456",
      vendor: "Samsung",
      node: "pve1",
      gpt: 1,
      mounted: 1,
      used: "LVM",
      wwn: "0x5002538e12345678"
    )

    @hdd_disk = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sdb",
      model: "WDC WD40EFRX-68N32N0",
      size: 4_000_787_030_016,
      type: "hdd",
      health: "PASSED",
      serial: "WD-WCC7K1234567",
      vendor: "Western Digital",
      node: "pve1",
      gpt: 1,
      mounted: 1,
      used: "ZFS",
      wwn: "0x50014ee265432100"
    )

    @minimal_disk = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sdc",
      size: 1_000_204_886_016,
      node: "pve2"
    )

    @presenter = Pvectl::Presenters::Disk.new
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Presenters::Disk
  end

  def test_inherits_from_base
    assert Pvectl::Presenters::Disk < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns
  # ---------------------------

  def test_columns
    assert_equal %w[NODE DEVICE MODEL SIZE TYPE HEALTH USED], @presenter.columns
  end

  def test_extra_columns
    assert_equal %w[SERIAL VENDOR WWN GPT MOUNTED], @presenter.extra_columns
  end

  def test_wide_columns
    expected = %w[NODE DEVICE MODEL SIZE TYPE HEALTH USED SERIAL VENDOR WWN GPT MOUNTED]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row
  # ---------------------------

  def test_to_row_with_ssd
    row = @presenter.to_row(@ssd_disk)

    assert_equal "pve1", row[0]       # NODE
    assert_equal "/dev/sda", row[1]   # DEVICE
    assert_equal "Samsung SSD 970 EVO Plus", row[2] # MODEL
    assert_equal "466 GB", row[3]     # SIZE
    assert_equal "ssd", row[4]        # TYPE
    assert_equal "PASSED", row[5]     # HEALTH
    assert_equal "LVM", row[6]        # USED
  end

  def test_to_row_with_hdd
    row = @presenter.to_row(@hdd_disk)

    assert_equal "3.6 TB", row[3]     # SIZE (4TB HDD)
    assert_equal "hdd", row[4]        # TYPE
  end

  def test_to_row_with_minimal_disk
    row = @presenter.to_row(@minimal_disk)

    assert_equal "pve2", row[0]       # NODE
    assert_equal "/dev/sdc", row[1]   # DEVICE
    assert_equal "-", row[2]          # MODEL (nil)
    assert_equal "932 GB", row[3]     # SIZE
    assert_equal "-", row[4]          # TYPE (nil)
    assert_equal "-", row[5]          # HEALTH (nil)
    assert_equal "-", row[6]          # USED (nil)
  end

  # ---------------------------
  # extra_values
  # ---------------------------

  def test_extra_values
    values = @presenter.extra_values(@ssd_disk)

    assert_equal "S4EWNX0M123456", values[0]         # SERIAL
    assert_equal "Samsung", values[1]                  # VENDOR
    assert_equal "0x5002538e12345678", values[2]       # WWN
    assert_equal "yes", values[3]                      # GPT
    assert_equal "yes", values[4]                      # MOUNTED
  end

  def test_extra_values_with_minimal_disk
    values = @presenter.extra_values(@minimal_disk)

    assert_equal "-", values[0]  # SERIAL
    assert_equal "-", values[1]  # VENDOR
    assert_equal "-", values[2]  # WWN
    assert_equal "-", values[3]  # GPT (nil)
    assert_equal "-", values[4]  # MOUNTED (nil)
  end

  # ---------------------------
  # to_hash
  # ---------------------------

  def test_to_hash
    hash = @presenter.to_hash(@ssd_disk)

    assert_equal "pve1", hash["node"]
    assert_equal "/dev/sda", hash["device"]
    assert_equal "Samsung SSD 970 EVO Plus", hash["model"]
    assert_equal 500_107_862_016, hash["size_bytes"]
    assert_in_delta 465.8, hash["size_gb"], 0.1
    assert_equal "ssd", hash["type"]
    assert_equal "PASSED", hash["health"]
    assert_equal "LVM", hash["used"]
    assert_equal "S4EWNX0M123456", hash["serial"]
    assert_equal "Samsung", hash["vendor"]
    assert_equal "0x5002538e12345678", hash["wwn"]
    assert_equal true, hash["gpt"]
    assert_equal true, hash["mounted"]
  end

  # ---------------------------
  # to_wide_row (inherited)
  # ---------------------------

  def test_to_wide_row_combines_row_and_extra
    wide = @presenter.to_wide_row(@ssd_disk)

    assert_equal 12, wide.size  # 7 columns + 5 extra
  end
end
