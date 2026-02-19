# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::TopVm Tests
# =============================================================================

class PresentersTopVmTest < Minitest::Test
  def setup
    @running_vm = Pvectl::Models::Vm.new(
      vmid: 100,
      name: "web-server",
      status: "running",
      node: "pve-node1",
      cpu: 0.23,
      maxcpu: 4,
      mem: 2_147_483_648,
      maxmem: 4_294_967_296,
      disk: 10_737_418_240,
      maxdisk: 53_687_091_200,
      uptime: 86_400,
      netin: 123_456_789,
      netout: 987_654_321
    )

    @stopped_vm = Pvectl::Models::Vm.new(
      vmid: 200,
      name: "dev-env",
      status: "stopped",
      node: "pve-node2",
      cpu: nil,
      maxcpu: 2,
      mem: nil,
      maxmem: 2_147_483_648,
      disk: nil,
      maxdisk: 32_212_254_720,
      uptime: nil,
      netin: nil,
      netout: nil
    )

    @presenter = Pvectl::Presenters::TopVm.new
  end

  # ---------------------------
  # Class Existence & Inheritance
  # ---------------------------

  def test_top_vm_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::TopVm
  end

  def test_inherits_from_vm_presenter
    assert_operator Pvectl::Presenters::TopVm, :<, Pvectl::Presenters::Vm
  end

  def test_includes_top_presenter
    assert_includes Pvectl::Presenters::TopVm.ancestors, Pvectl::Presenters::TopPresenter
  end

  # ---------------------------
  # Columns
  # ---------------------------

  def test_columns_returns_metrics_focused_headers
    expected = %w[VMID NAME NODE CPU(cores) CPU% MEMORY MEMORY%]
    assert_equal expected, @presenter.columns
  end

  def test_extra_columns_returns_wide_headers
    expected = %w[DISK DISK% NETIN NETOUT]
    assert_equal expected, @presenter.extra_columns
  end

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[VMID NAME NODE CPU(cores) CPU% MEMORY MEMORY% DISK DISK% NETIN NETOUT]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row (running VM)
  # ---------------------------

  def test_to_row_returns_vmid
    row = @presenter.to_row(@running_vm)
    assert_equal "100", row[0]
  end

  def test_to_row_returns_name
    row = @presenter.to_row(@running_vm)
    assert_equal "web-server", row[1]
  end

  def test_to_row_returns_node
    row = @presenter.to_row(@running_vm)
    assert_equal "pve-node1", row[2]
  end

  def test_to_row_returns_cpu_cores
    row = @presenter.to_row(@running_vm)
    assert_equal "4", row[3]
  end

  def test_to_row_returns_cpu_percent
    row = @presenter.to_row(@running_vm)
    assert_equal "23%", row[4]
  end

  def test_to_row_returns_memory_display
    row = @presenter.to_row(@running_vm)
    # 2_147_483_648 / GiB = 2.0, 4_294_967_296 / GiB = 4.0
    assert_equal "2.0/4.0 GB", row[5]
  end

  def test_to_row_returns_memory_percent
    row = @presenter.to_row(@running_vm)
    # 2_147_483_648 / 4_294_967_296 * 100 = 50
    assert_equal "50%", row[6]
  end

  # ---------------------------
  # to_row (stopped VM)
  # ---------------------------

  def test_to_row_stopped_returns_vmid
    row = @presenter.to_row(@stopped_vm)
    assert_equal "200", row[0]
  end

  def test_to_row_stopped_returns_dash_for_cpu_cores
    row = @presenter.to_row(@stopped_vm)
    assert_equal "2", row[3]
  end

  def test_to_row_stopped_returns_dash_for_cpu_percent
    row = @presenter.to_row(@stopped_vm)
    assert_equal "-", row[4]
  end

  def test_to_row_stopped_returns_dash_for_memory
    row = @presenter.to_row(@stopped_vm)
    assert_equal "-/2.0 GB", row[5]
  end

  def test_to_row_stopped_returns_dash_for_memory_percent
    row = @presenter.to_row(@stopped_vm)
    assert_equal "-", row[6]
  end

  # ---------------------------
  # extra_values (wide)
  # ---------------------------

  def test_extra_values_returns_disk_display
    values = @presenter.extra_values(@running_vm)
    # 10_737_418_240 / GiB ≈ 10, 53_687_091_200 / GiB ≈ 50
    assert_equal "10/50 GB", values[0]
  end

  def test_extra_values_returns_disk_percent
    values = @presenter.extra_values(@running_vm)
    # 10_737_418_240 / 53_687_091_200 * 100 = 20
    assert_equal "20%", values[1]
  end

  def test_extra_values_returns_netin
    values = @presenter.extra_values(@running_vm)
    # 123_456_789 bytes ≈ 117.7 MiB
    assert_match(/MiB/, values[2])
  end

  def test_extra_values_returns_netout
    values = @presenter.extra_values(@running_vm)
    # 987_654_321 bytes ≈ 941.9 MiB
    assert_match(/MiB/, values[3])
  end

  def test_extra_values_stopped_returns_dash_for_disk
    values = @presenter.extra_values(@stopped_vm)
    assert_equal "-", values[0]
  end

  def test_extra_values_stopped_returns_dash_for_disk_percent
    values = @presenter.extra_values(@stopped_vm)
    assert_equal "-", values[1]
  end

  def test_extra_values_stopped_returns_dash_for_netin
    values = @presenter.extra_values(@stopped_vm)
    assert_equal "-", values[2]
  end

  def test_extra_values_stopped_returns_dash_for_netout
    values = @presenter.extra_values(@stopped_vm)
    assert_equal "-", values[3]
  end

  # ---------------------------
  # to_hash (JSON/YAML)
  # ---------------------------

  def test_to_hash_returns_vmid
    hash = @presenter.to_hash(@running_vm)
    assert_equal 100, hash["vmid"]
  end

  def test_to_hash_returns_name
    hash = @presenter.to_hash(@running_vm)
    assert_equal "web-server", hash["name"]
  end

  def test_to_hash_returns_node
    hash = @presenter.to_hash(@running_vm)
    assert_equal "pve-node1", hash["node"]
  end

  def test_to_hash_returns_cpu_section
    hash = @presenter.to_hash(@running_vm)
    assert_equal 23, hash["cpu"]["usage_percent"]
    assert_equal 4, hash["cpu"]["cores"]
  end

  def test_to_hash_returns_memory_section
    hash = @presenter.to_hash(@running_vm)
    assert hash["memory"].key?("used_bytes")
    assert hash["memory"].key?("total_bytes")
    assert hash["memory"].key?("usage_percent")
  end

  def test_to_hash_returns_disk_section
    hash = @presenter.to_hash(@running_vm)
    assert hash["disk"].key?("used_bytes")
    assert hash["disk"].key?("total_bytes")
    assert hash["disk"].key?("usage_percent")
  end

  def test_to_hash_returns_network_section
    hash = @presenter.to_hash(@running_vm)
    assert_equal 123_456_789, hash["network"]["in_bytes"]
    assert_equal 987_654_321, hash["network"]["out_bytes"]
  end

  def test_to_hash_does_not_include_operational_info
    hash = @presenter.to_hash(@running_vm)
    refute hash.key?("status")
    refute hash.key?("template")
    refute hash.key?("tags")
    refute hash.key?("ha")
    refute hash.key?("uptime")
  end
end
