# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::Node Tests
# =============================================================================

class ModelsNodeTest < Minitest::Test
  # Tests for the Node domain model
  # Display methods have been moved to Presenters::Node

  def setup
    @online_node_attrs = {
      name: "pve-node1",
      status: "online",
      cpu: 0.23,
      maxcpu: 32,
      mem: 48_535_150_182,         # ~45.2 GB
      maxmem: 137_438_953_472,     # 128 GB
      disk: 1_288_490_188_800,     # ~1.2 TB
      maxdisk: 4_398_046_511_104,  # 4 TB
      uptime: 3_898_800,           # ~45 days 3 hours
      level: "c",
      version: "8.3.2",
      kernel: "6.8.12-1-pve",
      loadavg: [0.45, 0.52, 0.48],
      swap_used: 0,
      swap_total: 8_589_934_592,   # 8 GB
      guests_vms: 28,
      guests_cts: 14
    }

    @offline_node_attrs = {
      name: "pve-node4",
      status: "offline",
      cpu: nil,
      maxcpu: 16,
      mem: nil,
      maxmem: 68_719_476_736,      # 64 GB
      disk: nil,
      maxdisk: 2_199_023_255_552,  # 2 TB
      uptime: nil,
      level: "c",
      version: nil,
      kernel: nil,
      loadavg: nil,
      swap_used: nil,
      swap_total: nil,
      guests_vms: 0,
      guests_cts: 0
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_node_class_exists
    assert_kind_of Class, Pvectl::Models::Node
  end

  def test_node_inherits_from_base
    assert Pvectl::Models::Node < Pvectl::Models::Base
  end

  # ---------------------------
  # Attribute Readers
  # ---------------------------

  def test_name_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal "pve-node1", node.name
  end

  def test_name_attribute_from_node_key
    # API sometimes uses "node" instead of "name"
    attrs = { node: "pve-test", status: "online" }
    node = Pvectl::Models::Node.new(attrs)
    assert_equal "pve-test", node.name
  end

  def test_status_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal "online", node.status
  end

  def test_cpu_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 0.23, node.cpu
  end

  def test_maxcpu_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 32, node.maxcpu
  end

  def test_mem_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 48_535_150_182, node.mem
  end

  def test_maxmem_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 137_438_953_472, node.maxmem
  end

  def test_disk_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 1_288_490_188_800, node.disk
  end

  def test_maxdisk_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 4_398_046_511_104, node.maxdisk
  end

  def test_uptime_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 3_898_800, node.uptime
  end

  def test_level_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal "c", node.level
  end

  def test_version_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal "8.3.2", node.version
  end

  def test_kernel_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal "6.8.12-1-pve", node.kernel
  end

  def test_loadavg_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [0.45, 0.52, 0.48], node.loadavg
  end

  def test_swap_used_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 0, node.swap_used
  end

  def test_swap_total_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 8_589_934_592, node.swap_total
  end

  def test_guests_vms_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 28, node.guests_vms
  end

  def test_guests_cts_attribute
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 14, node.guests_cts
  end

  def test_guests_vms_defaults_to_zero
    attrs = { name: "test", status: "online" }
    node = Pvectl::Models::Node.new(attrs)
    assert_equal 0, node.guests_vms
  end

  def test_guests_cts_defaults_to_zero
    attrs = { name: "test", status: "online" }
    node = Pvectl::Models::Node.new(attrs)
    assert_equal 0, node.guests_cts
  end

  # ---------------------------
  # Status Predicate Methods
  # ---------------------------

  def test_online_returns_true_for_online_node
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert node.online?
  end

  def test_online_returns_false_for_offline_node
    node = Pvectl::Models::Node.new(@offline_node_attrs)
    refute node.online?
  end

  def test_offline_returns_true_for_offline_node
    node = Pvectl::Models::Node.new(@offline_node_attrs)
    assert node.offline?
  end

  def test_offline_returns_false_for_online_node
    node = Pvectl::Models::Node.new(@online_node_attrs)
    refute node.offline?
  end

  # ---------------------------
  # Guests Total Method
  # ---------------------------

  def test_guests_total_returns_sum_of_vms_and_cts
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 42, node.guests_total
  end

  def test_guests_total_returns_zero_when_no_guests
    node = Pvectl::Models::Node.new(@offline_node_attrs)
    assert_equal 0, node.guests_total
  end

  # ---------------------------
  # String Keys in Attributes
  # ---------------------------

  def test_accepts_string_keys
    string_attrs = {
      "name" => "pve-test",
      "status" => "online",
      "cpu" => 0.5,
      "maxcpu" => 8
    }
    node = Pvectl::Models::Node.new(string_attrs)
    assert_equal "pve-test", node.name
    assert_equal 0.5, node.cpu
  end

  # ---------------------------
  # IP Attribute
  # ---------------------------

  def test_ip_attribute_when_set
    attrs = @online_node_attrs.merge(ip: "192.168.1.10")
    node = Pvectl::Models::Node.new(attrs)
    assert_equal "192.168.1.10", node.ip
  end

  def test_ip_attribute_when_nil
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_nil node.ip
  end

  # ---------------------------
  # Extended Attributes for Describe
  # ---------------------------

  def test_cpuinfo_attribute
    attrs = @online_node_attrs.merge(cpuinfo: { model: "AMD EPYC 7302", cores: 16, sockets: 2 })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ model: "AMD EPYC 7302", cores: 16, sockets: 2 }, node.cpuinfo)
  end

  def test_cpuinfo_defaults_to_nil
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_nil node.cpuinfo
  end

  def test_boot_info_attribute
    attrs = @online_node_attrs.merge(boot_info: { mode: "efi" })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ mode: "efi" }, node.boot_info)
  end

  def test_rootfs_attribute
    attrs = @online_node_attrs.merge(rootfs: { used: 1_288_490_188_800, total: 4_398_046_511_104 })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ used: 1_288_490_188_800, total: 4_398_046_511_104 }, node.rootfs)
  end

  def test_subscription_attribute
    attrs = @online_node_attrs.merge(subscription: { status: "Active", level: "c" })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ status: "Active", level: "c" }, node.subscription)
  end

  def test_dns_attribute
    attrs = @online_node_attrs.merge(dns: { search: "example.com", dns1: "192.168.1.1" })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ search: "example.com", dns1: "192.168.1.1" }, node.dns)
  end

  def test_time_info_attribute
    attrs = @online_node_attrs.merge(time_info: { timezone: "Europe/Warsaw", localtime: 1705326765 })
    node = Pvectl::Models::Node.new(attrs)
    assert_equal({ timezone: "Europe/Warsaw", localtime: 1705326765 }, node.time_info)
  end

  def test_network_interfaces_attribute
    interfaces = [{ iface: "vmbr0", type: "bridge", address: "192.168.1.10" }]
    attrs = @online_node_attrs.merge(network_interfaces: interfaces)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal interfaces, node.network_interfaces
  end

  def test_network_interfaces_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.network_interfaces
  end

  def test_services_attribute
    services = [{ service: "pve-cluster", state: "running", desc: "PVE Cluster" }]
    attrs = @online_node_attrs.merge(services: services)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal services, node.services
  end

  def test_services_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.services
  end

  def test_storage_pools_attribute
    pools = [{ storage: "local", type: "dir", total: 100_000_000_000 }]
    attrs = @online_node_attrs.merge(storage_pools: pools)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal pools, node.storage_pools
  end

  def test_storage_pools_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.storage_pools
  end

  def test_physical_disks_attribute
    disks = [{ devpath: "/dev/sda", model: "Samsung SSD", size: 500_000_000_000 }]
    attrs = @online_node_attrs.merge(physical_disks: disks)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal disks, node.physical_disks
  end

  def test_physical_disks_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.physical_disks
  end

  def test_qemu_cpu_models_attribute
    models = [{ name: "host" }, { name: "max" }]
    attrs = @online_node_attrs.merge(qemu_cpu_models: models)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal models, node.qemu_cpu_models
  end

  def test_qemu_cpu_models_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.qemu_cpu_models
  end

  def test_qemu_machines_attribute
    machines = [{ id: "pc-q35-8.1" }, { id: "pc-i440fx-8.1" }]
    attrs = @online_node_attrs.merge(qemu_machines: machines)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal machines, node.qemu_machines
  end

  def test_qemu_machines_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.qemu_machines
  end

  def test_updates_available_attribute
    attrs = @online_node_attrs.merge(updates_available: 5)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal 5, node.updates_available
  end

  def test_updates_available_defaults_to_zero
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal 0, node.updates_available
  end

  def test_updates_attribute
    updates = [{ Package: "pve-manager", CurrentVersion: "8.3.1", AvailableVersion: "8.3.2" }]
    attrs = @online_node_attrs.merge(updates: updates)
    node = Pvectl::Models::Node.new(attrs)
    assert_equal updates, node.updates
  end

  def test_updates_defaults_to_empty_array
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_equal [], node.updates
  end

  def test_offline_note_attribute
    attrs = @offline_node_attrs.merge(offline_note: "Node offline - detailed metrics unavailable")
    node = Pvectl::Models::Node.new(attrs)
    assert_equal "Node offline - detailed metrics unavailable", node.offline_note
  end

  def test_offline_note_defaults_to_nil
    node = Pvectl::Models::Node.new(@online_node_attrs)
    assert_nil node.offline_note
  end
end
