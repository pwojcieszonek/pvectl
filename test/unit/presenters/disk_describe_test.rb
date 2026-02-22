# frozen_string_literal: true

require "test_helper"

class DiskPresenterDescribeTest < Minitest::Test
  def setup
    @presenter = Pvectl::Presenters::Disk.new
  end

  # ---------------------------
  # to_description — Device Info section
  # ---------------------------

  def test_to_description_returns_hash
    disk = build_disk

    result = @presenter.to_description(disk)

    assert_instance_of Hash, result
  end

  def test_to_description_has_device_info_section
    disk = build_disk

    result = @presenter.to_description(disk)

    assert result.key?("Device Info"), "Expected 'Device Info' section"
    info = result["Device Info"]
    assert_equal "pve1", info["Node"]
    assert_equal "/dev/nvme0n1", info["Device"]
    assert_equal "Samsung SSD 970", info["Model"]
    assert_equal "nvme", info["Type"]
    assert_equal "PASSED", info["Health"]
  end

  def test_to_description_device_info_includes_size
    disk = build_disk(size: 1_000_204_886_016)

    result = @presenter.to_description(disk)

    assert_equal "932 GB", result["Device Info"]["Size"]
  end

  def test_to_description_device_info_includes_life_remaining_when_present
    disk = build_disk(wearout: 96)

    result = @presenter.to_description(disk)

    assert_equal "96%", result["Device Info"]["Life Remaining"]
  end

  def test_to_description_device_info_omits_life_remaining_when_nil
    disk = build_disk(wearout: nil)

    result = @presenter.to_description(disk)

    refute result["Device Info"].key?("Life Remaining")
  end

  def test_to_description_device_info_does_not_include_mounted
    disk = build_disk(mounted: 1)

    result = @presenter.to_description(disk)

    refute result["Device Info"].key?("Mounted")
  end

  # ---------------------------
  # to_description — SMART Attributes (NVMe/SAS text)
  # ---------------------------

  def test_to_description_smart_section_from_text
    text = "Critical Warning:                   0x00\nTemperature:                        34 Celsius\n"
    disk = build_disk(smart_type: "text", smart_text: text)

    result = @presenter.to_description(disk)

    assert result.key?("SMART Attributes"), "Expected 'SMART Attributes' section"
    attrs = result["SMART Attributes"]
    assert_instance_of Array, attrs
    assert_equal 2, attrs.size
    assert_equal "Critical Warning", attrs[0]["Attribute"]
    assert_equal "0x00", attrs[0]["Value"]
  end

  # ---------------------------
  # to_description — SMART Attributes (ATA)
  # ---------------------------

  def test_to_description_smart_section_from_ata_attributes
    ata_attrs = [
      { id: 1, name: "Raw_Read_Error_Rate", value: 200, worst: 200, threshold: 51, raw: "0", fail: "-", flags: "0x002f" },
      { id: 9, name: "Power_On_Hours", value: 89, worst: 89, threshold: 0, raw: "8382", fail: "-", flags: "0x0032" }
    ]
    disk = build_disk(type: "ssd", smart_type: "ata", smart_attributes: ata_attrs)

    result = @presenter.to_description(disk)

    attrs = result["SMART Attributes"]
    assert_instance_of Array, attrs
    assert_equal 2, attrs.size
    assert_equal "1", attrs[0]["ID"]
    assert_equal "Raw_Read_Error_Rate", attrs[0]["Attribute"]
    assert_equal "200", attrs[0]["Value"]
    assert_equal "200", attrs[0]["Worst"]
    assert_equal "51", attrs[0]["Threshold"]
    assert_equal "0", attrs[0]["Raw"]
    assert_equal "-", attrs[0]["Fail"]
  end

  # ---------------------------
  # to_description — No SMART data
  # ---------------------------

  def test_to_description_without_smart_data
    disk = build_disk(smart_type: nil)

    result = @presenter.to_description(disk)

    assert result.key?("Device Info")
    refute result.key?("SMART Attributes")
  end

  private

  def build_disk(overrides = {})
    defaults = {
      devpath: "/dev/nvme0n1", model: "Samsung SSD 970", size: 1_000_204_886_016,
      type: "nvme", health: "PASSED", serial: "S4EWNX0R417XXX", vendor: "Samsung",
      node: "pve1", gpt: 1, mounted: 0, used: "BIOS boot", wwn: "5002538e403d3xxx",
      smart_type: nil, smart_attributes: nil, smart_text: nil, wearout: nil
    }
    Pvectl::Models::PhysicalDisk.new(defaults.merge(overrides))
  end
end
