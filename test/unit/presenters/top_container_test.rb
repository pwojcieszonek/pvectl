# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::TopContainer Tests
# =============================================================================

class PresentersTopContainerTest < Minitest::Test
  def setup
    @running_ct = Pvectl::Models::Container.new(
      vmid: 100,
      name: "web-proxy",
      status: "running",
      node: "pve-node1",
      cpu: 0.15,
      maxcpu: 2,
      mem: 536_870_912,
      maxmem: 1_073_741_824,
      swap: 26_214_400,
      maxswap: 536_870_912,
      disk: 2_147_483_648,
      maxdisk: 10_737_418_240,
      uptime: 172_800,
      netin: 56_789_012,
      netout: 12_345_678
    )

    @stopped_ct = Pvectl::Models::Container.new(
      vmid: 200,
      name: "dev-ct",
      status: "stopped",
      node: "pve-node2",
      cpu: nil,
      maxcpu: 1,
      mem: nil,
      maxmem: 536_870_912,
      swap: nil,
      maxswap: 268_435_456,
      disk: nil,
      maxdisk: 5_368_709_120,
      uptime: nil,
      netin: nil,
      netout: nil
    )

    @presenter = Pvectl::Presenters::TopContainer.new
  end

  # ---------------------------
  # Class Existence & Inheritance
  # ---------------------------

  def test_top_container_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::TopContainer
  end

  def test_inherits_from_container_presenter
    assert_operator Pvectl::Presenters::TopContainer, :<, Pvectl::Presenters::Container
  end

  def test_includes_top_presenter
    assert_includes Pvectl::Presenters::TopContainer.ancestors, Pvectl::Presenters::TopPresenter
  end

  # ---------------------------
  # Columns
  # ---------------------------

  def test_columns_returns_metrics_focused_headers
    expected = %w[CTID NAME NODE CPU(cores) CPU% MEMORY MEMORY%]
    assert_equal expected, @presenter.columns
  end

  def test_extra_columns_returns_wide_headers
    expected = %w[SWAP SWAP% DISK DISK% NETIN NETOUT]
    assert_equal expected, @presenter.extra_columns
  end

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[CTID NAME NODE CPU(cores) CPU% MEMORY MEMORY% SWAP SWAP% DISK DISK% NETIN NETOUT]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row (running CT)
  # ---------------------------

  def test_to_row_returns_ctid
    row = @presenter.to_row(@running_ct)
    assert_equal "100", row[0]
  end

  def test_to_row_returns_name
    row = @presenter.to_row(@running_ct)
    assert_equal "web-proxy", row[1]
  end

  def test_to_row_returns_node
    row = @presenter.to_row(@running_ct)
    assert_equal "pve-node1", row[2]
  end

  def test_to_row_returns_cpu_cores
    row = @presenter.to_row(@running_ct)
    assert_equal "2", row[3]
  end

  def test_to_row_returns_cpu_percent
    row = @presenter.to_row(@running_ct)
    assert_equal "15%", row[4]
  end

  def test_to_row_returns_memory_display
    row = @presenter.to_row(@running_ct)
    # 536_870_912 / GiB = 0.5, 1_073_741_824 / GiB = 1.0
    assert_equal "0.5/1.0 GiB", row[5]
  end

  def test_to_row_returns_memory_percent
    row = @presenter.to_row(@running_ct)
    # 536_870_912 / 1_073_741_824 * 100 = 50
    assert_equal "50%", row[6]
  end

  # ---------------------------
  # to_row (stopped CT)
  # ---------------------------

  def test_to_row_stopped_returns_ctid
    row = @presenter.to_row(@stopped_ct)
    assert_equal "200", row[0]
  end

  def test_to_row_stopped_returns_cores
    row = @presenter.to_row(@stopped_ct)
    assert_equal "1", row[3]
  end

  def test_to_row_stopped_returns_dash_for_cpu_percent
    row = @presenter.to_row(@stopped_ct)
    assert_equal "-", row[4]
  end

  def test_to_row_stopped_returns_dash_for_memory
    row = @presenter.to_row(@stopped_ct)
    assert_equal "-/0.5 GiB", row[5]
  end

  def test_to_row_stopped_returns_dash_for_memory_percent
    row = @presenter.to_row(@stopped_ct)
    assert_equal "-", row[6]
  end

  # ---------------------------
  # extra_values (wide)
  # ---------------------------

  def test_extra_values_returns_swap_display
    values = @presenter.extra_values(@running_ct)
    # 26_214_400 / MiB = 25, 536_870_912 / MiB = 512
    assert_equal "25/512 MiB", values[0]
  end

  def test_extra_values_returns_swap_percent
    values = @presenter.extra_values(@running_ct)
    # 26_214_400 / 536_870_912 * 100 ≈ 5
    assert_equal "5%", values[1]
  end

  def test_extra_values_returns_disk_display
    values = @presenter.extra_values(@running_ct)
    # 2_147_483_648 / GiB = 2.0, 10_737_418_240 / GiB = 10.0
    assert_equal "2.0/10.0 GiB", values[2]
  end

  def test_extra_values_returns_disk_percent
    values = @presenter.extra_values(@running_ct)
    # 2_147_483_648 / 10_737_418_240 * 100 = 20
    assert_equal "20%", values[3]
  end

  def test_extra_values_returns_netin
    values = @presenter.extra_values(@running_ct)
    assert_match(/MiB/, values[4])
  end

  def test_extra_values_returns_netout
    values = @presenter.extra_values(@running_ct)
    assert_match(/MiB/, values[5])
  end

  def test_extra_values_stopped_returns_dash_for_swap
    values = @presenter.extra_values(@stopped_ct)
    assert_match(%r{-/\d+ MiB}, values[0])
  end

  def test_extra_values_stopped_returns_dash_for_swap_percent
    values = @presenter.extra_values(@stopped_ct)
    assert_equal "-", values[1]
  end

  # ---------------------------
  # to_hash (JSON/YAML)
  # ---------------------------

  def test_to_hash_returns_ctid
    hash = @presenter.to_hash(@running_ct)
    assert_equal 100, hash["ctid"]
  end

  def test_to_hash_returns_name
    hash = @presenter.to_hash(@running_ct)
    assert_equal "web-proxy", hash["name"]
  end

  def test_to_hash_returns_node
    hash = @presenter.to_hash(@running_ct)
    assert_equal "pve-node1", hash["node"]
  end

  def test_to_hash_returns_cpu_section
    hash = @presenter.to_hash(@running_ct)
    assert_equal 15, hash["cpu"]["usage_percent"]
    assert_equal 2, hash["cpu"]["cores"]
  end

  def test_to_hash_returns_memory_section
    hash = @presenter.to_hash(@running_ct)
    assert hash["memory"].key?("used_bytes")
    assert hash["memory"].key?("total_bytes")
    assert hash["memory"].key?("usage_percent")
  end

  def test_to_hash_returns_swap_section
    hash = @presenter.to_hash(@running_ct)
    assert hash["swap"].key?("used_bytes")
    assert hash["swap"].key?("total_bytes")
    assert hash["swap"].key?("usage_percent")
  end

  def test_to_hash_returns_disk_section
    hash = @presenter.to_hash(@running_ct)
    assert hash["disk"].key?("used_bytes")
    assert hash["disk"].key?("total_bytes")
    assert hash["disk"].key?("usage_percent")
  end

  def test_to_hash_returns_network_section
    hash = @presenter.to_hash(@running_ct)
    assert_equal 56_789_012, hash["network"]["in_bytes"]
    assert_equal 12_345_678, hash["network"]["out_bytes"]
  end

  def test_to_hash_does_not_include_operational_info
    hash = @presenter.to_hash(@running_ct)
    refute hash.key?("status")
    refute hash.key?("template")
    refute hash.key?("tags")
    refute hash.key?("pool")
    refute hash.key?("uptime")
  end
end
