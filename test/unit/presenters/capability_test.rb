# frozen_string_literal: true

require "test_helper"

class PresentersCapabilityTest < Minitest::Test
  def setup
    @cpu_cap = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :cpu, name: "host", vendor: "GenuineIntel"
    )

    @custom_cpu = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :cpu, name: "custom-mycpu",
      vendor: "GenuineIntel", custom: true
    )

    @machine_cap = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :machine, name: "pc-q35-8.1",
      machine_type: "q35", version: "8.1"
    )

    @presenter = Pvectl::Presenters::Capability.new
  end

  def test_columns
    assert_equal ["NODE", "KIND", "NAME", "DETAILS"], @presenter.columns
  end

  def test_extra_columns_include_version
    assert_includes @presenter.extra_columns, "VERSION"
  end

  def test_cpu_row_has_vendor_in_details
    row = @presenter.to_row(@cpu_cap)

    assert_equal "pve1", row[0]
    assert_equal "cpu", row[1]
    assert_equal "host", row[2]
    assert_match(/GenuineIntel/, row[3])
  end

  def test_custom_cpu_row_marks_custom
    row = @presenter.to_row(@custom_cpu)
    assert_match(/custom/, row[3])
  end

  def test_machine_row_shows_machine_type
    row = @presenter.to_row(@machine_cap)

    assert_equal "machine", row[1]
    assert_equal "pc-q35-8.1", row[2]
    assert_equal "q35", row[3]
  end

  def test_to_hash_cpu_omits_machine_fields
    h = @presenter.to_hash(@cpu_cap)
    assert_equal "cpu", h["kind"]
    assert_equal "GenuineIntel", h["vendor"]
    refute h.key?("machine_type")
    refute h.key?("version")
  end

  def test_to_hash_machine_includes_version_and_type
    h = @presenter.to_hash(@machine_cap)
    assert_equal "machine", h["kind"]
    assert_equal "q35", h["machine_type"]
    assert_equal "8.1", h["version"]
  end

  def test_wide_row_includes_version
    row = @presenter.to_wide_row(@machine_cap)
    assert_includes row, "8.1"
  end
end
