# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::TopNode Tests
# =============================================================================

class PresentersTopNodeTest < Minitest::Test
  def setup
    @online_node = Pvectl::Models::Node.new(
      name: "pve-node1",
      status: "online",
      cpu: 0.23,
      maxcpu: 32,
      mem: 48_535_150_182,
      maxmem: 137_438_953_472,
      disk: 1_288_490_188_800,
      maxdisk: 4_398_046_511_104,
      uptime: 3_898_800,
      loadavg: [0.45, 0.52, 0.48],
      swap_used: 0,
      swap_total: 8_589_934_592,
      guests_vms: 28,
      guests_cts: 14
    )

    @offline_node = Pvectl::Models::Node.new(
      name: "pve-node4",
      status: "offline",
      cpu: nil,
      maxcpu: 16,
      mem: nil,
      maxmem: 68_719_476_736,
      disk: nil,
      maxdisk: 2_199_023_255_552,
      uptime: nil,
      loadavg: nil,
      swap_used: nil,
      swap_total: nil,
      guests_vms: 0,
      guests_cts: 0
    )

    @presenter = Pvectl::Presenters::TopNode.new
  end

  # ---------------------------
  # Class Existence & Inheritance
  # ---------------------------

  def test_top_node_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::TopNode
  end

  def test_inherits_from_node_presenter
    assert_operator Pvectl::Presenters::TopNode, :<, Pvectl::Presenters::Node
  end

  def test_includes_top_presenter
    assert_includes Pvectl::Presenters::TopNode.ancestors, Pvectl::Presenters::TopPresenter
  end

  # ---------------------------
  # Columns
  # ---------------------------

  def test_columns_returns_metrics_focused_headers
    expected = %w[NAME CPU(cores) CPU% MEMORY MEMORY%]
    assert_equal expected, @presenter.columns
  end

  def test_extra_columns_returns_wide_headers
    expected = %w[DISK DISK% SWAP SWAP% LOAD GUESTS]
    assert_equal expected, @presenter.extra_columns
  end

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[NAME CPU(cores) CPU% MEMORY MEMORY% DISK DISK% SWAP SWAP% LOAD GUESTS]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row (online node)
  # ---------------------------

  def test_to_row_returns_name
    row = @presenter.to_row(@online_node)
    assert_equal "pve-node1", row[0]
  end

  def test_to_row_returns_cpu_cores
    row = @presenter.to_row(@online_node)
    assert_equal "32", row[1]
  end

  def test_to_row_returns_cpu_percent
    row = @presenter.to_row(@online_node)
    assert_equal "23%", row[2]
  end

  def test_to_row_returns_memory_display
    row = @presenter.to_row(@online_node)
    # 48_535_150_182 / GiB = ~45.2, 137_438_953_472 / GiB = 128
    assert_equal "45.2/128 GB", row[3]
  end

  def test_to_row_returns_memory_percent
    row = @presenter.to_row(@online_node)
    # 48_535_150_182 / 137_438_953_472 * 100 ≈ 35.3 → "35%"
    assert_equal "35%", row[4]
  end

  # ---------------------------
  # to_row (offline node)
  # ---------------------------

  def test_to_row_offline_returns_name
    row = @presenter.to_row(@offline_node)
    assert_equal "pve-node4", row[0]
  end

  def test_to_row_offline_returns_dash_for_cores
    row = @presenter.to_row(@offline_node)
    assert_equal "-", row[1]
  end

  def test_to_row_offline_returns_dash_for_cpu_percent
    row = @presenter.to_row(@offline_node)
    assert_equal "-", row[2]
  end

  def test_to_row_offline_returns_dash_for_memory
    row = @presenter.to_row(@offline_node)
    assert_equal "-", row[3]
  end

  def test_to_row_offline_returns_dash_for_memory_percent
    row = @presenter.to_row(@offline_node)
    assert_equal "-", row[4]
  end

  # ---------------------------
  # extra_values (wide)
  # ---------------------------

  def test_extra_values_returns_disk_display
    values = @presenter.extra_values(@online_node)
    # 1_288_490_188_800 / 4_398_046_511_104 → ~1.2/4.1 TB (both >= 1024 GB)
    assert_match(/\d.*\/.*\d.*TB/, values[0])
  end

  def test_extra_values_returns_disk_percent
    values = @presenter.extra_values(@online_node)
    # 1_288_490_188_800 / 4_398_046_511_104 * 100 ≈ 29.3 → "29%"
    assert_equal "29%", values[1]
  end

  def test_extra_values_returns_swap_display
    values = @presenter.extra_values(@online_node)
    assert_equal "0.0/8 GB", values[2]
  end

  def test_extra_values_returns_swap_percent
    values = @presenter.extra_values(@online_node)
    assert_equal "0%", values[3]
  end

  def test_extra_values_returns_load_display
    values = @presenter.extra_values(@online_node)
    assert_equal "0.45", values[4]
  end

  def test_extra_values_returns_guests_total
    values = @presenter.extra_values(@online_node)
    assert_equal "42", values[5]
  end

  def test_extra_values_offline_returns_dashes
    values = @presenter.extra_values(@offline_node)
    assert_equal "-", values[0]  # disk
    assert_equal "-", values[1]  # disk%
    assert_equal "-", values[2]  # swap
    assert_equal "-", values[3]  # swap%
    assert_equal "-", values[4]  # load
    assert_equal "0", values[5]  # guests (0, not dash)
  end

  # ---------------------------
  # to_hash (JSON/YAML)
  # ---------------------------

  def test_to_hash_returns_name
    hash = @presenter.to_hash(@online_node)
    assert_equal "pve-node1", hash["name"]
  end

  def test_to_hash_returns_cpu_section
    hash = @presenter.to_hash(@online_node)
    assert_equal 23, hash["cpu"]["usage_percent"]
    assert_equal 32, hash["cpu"]["cores"]
  end

  def test_to_hash_returns_memory_section
    hash = @presenter.to_hash(@online_node)
    assert hash["memory"].key?("used_bytes")
    assert hash["memory"].key?("total_bytes")
    assert hash["memory"].key?("usage_percent")
  end

  def test_to_hash_returns_disk_section
    hash = @presenter.to_hash(@online_node)
    assert hash["disk"].key?("used_bytes")
    assert hash["disk"].key?("total_bytes")
    assert hash["disk"].key?("usage_percent")
  end

  def test_to_hash_returns_swap_section
    hash = @presenter.to_hash(@online_node)
    assert hash["swap"].key?("used_bytes")
    assert hash["swap"].key?("total_bytes")
    assert hash["swap"].key?("usage_percent")
  end

  def test_to_hash_returns_load_section
    hash = @presenter.to_hash(@online_node)
    assert_equal 0.45, hash["load"]["avg1"]
  end

  def test_to_hash_returns_guests_section
    hash = @presenter.to_hash(@online_node)
    assert_equal 42, hash["guests"]["total"]
  end

  def test_to_hash_does_not_include_operational_info
    hash = @presenter.to_hash(@online_node)
    refute hash.key?("version")
    refute hash.key?("kernel")
    refute hash.key?("uptime")
    refute hash.key?("alerts")
    refute hash.key?("network")
    refute hash.key?("status")
  end
end
