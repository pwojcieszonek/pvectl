# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Node Tests
# =============================================================================

class PresentersNodeTest < Minitest::Test
  # Tests for the Node presenter

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
      level: "c",
      version: "8.3.2",
      kernel: "6.8.12-1-pve",
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
      level: "c",
      version: nil,
      kernel: nil,
      loadavg: nil,
      swap_used: nil,
      swap_total: nil,
      guests_vms: 0,
      guests_cts: 0
    )

    @high_load_node = Pvectl::Models::Node.new(
      name: "pve-node2",
      status: "online",
      cpu: 0.67,
      maxcpu: 32,
      mem: 95_695_953_920,
      maxmem: 137_438_953_472,
      disk: 3_006_477_107_200,
      maxdisk: 4_398_046_511_104,
      uptime: 3_898_800,
      level: "c",
      version: "8.3.2",
      kernel: "6.8.12-1-pve",
      loadavg: [2.31, 1.85, 1.42],
      swap_used: 2_254_857_830,
      swap_total: 8_589_934_592,
      guests_vms: 25,
      guests_cts: 13
    )

    @presenter = Pvectl::Presenters::Node.new
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_node_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::Node
  end

  def test_node_presenter_inherits_from_base
    assert Pvectl::Presenters::Node < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns() Method
  # ---------------------------

  def test_columns_returns_expected_headers
    expected = %w[NAME STATUS VERSION CPU MEMORY GUESTS UPTIME]
    assert_equal expected, @presenter.columns
  end

  # ---------------------------
  # extra_columns() Method
  # ---------------------------

  def test_extra_columns_returns_wide_headers
    expected = %w[LOAD SWAP STORAGE VMS CTS KERNEL IP]
    assert_equal expected, @presenter.extra_columns
  end

  # ---------------------------
  # wide_columns() Method
  # ---------------------------

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[NAME STATUS VERSION CPU MEMORY GUESTS UPTIME LOAD SWAP STORAGE VMS CTS KERNEL IP]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row() Method - Online Node
  # ---------------------------

  def test_to_row_for_online_node
    row = @presenter.to_row(@online_node)

    assert_equal "pve-node1", row[0]     # NAME
    assert_equal "online", row[1]         # STATUS
    assert_equal "8.3.2", row[2]          # VERSION
    assert_equal "23%", row[3]            # CPU
    assert_equal "45.2/128 GB", row[4]    # MEMORY
    assert_equal "42", row[5]             # GUESTS
    assert_equal "45d 3h", row[6]         # UPTIME
  end

  # ---------------------------
  # to_row() Method - Offline Node
  # ---------------------------

  def test_to_row_for_offline_node
    row = @presenter.to_row(@offline_node)

    assert_equal "pve-node4", row[0]  # NAME
    assert_equal "offline", row[1]     # STATUS
    assert_equal "-", row[2]           # VERSION (nil)
    assert_equal "-", row[3]           # CPU (offline)
    assert_equal "-", row[4]           # MEMORY (offline)
    assert_equal "0", row[5]           # GUESTS
    assert_equal "-", row[6]           # UPTIME (offline)
  end

  # ---------------------------
  # extra_values() Method
  # ---------------------------

  def test_extra_values_for_online_node
    extra = @presenter.extra_values(@online_node)

    assert_equal "0.45", extra[0]         # LOAD
    assert_equal "0.0/8 GB", extra[1]     # SWAP
    assert_equal "1.2/4.0 TB", extra[2]   # STORAGE
    assert_equal "28", extra[3]           # VMS
    assert_equal "14", extra[4]           # CTS
    assert_equal "6.8.12-1-pve", extra[5] # KERNEL
  end

  def test_extra_values_for_offline_node
    extra = @presenter.extra_values(@offline_node)

    assert_equal "-", extra[0]   # LOAD
    assert_equal "-", extra[1]   # SWAP
    assert_equal "-", extra[2]   # STORAGE
    assert_equal "0", extra[3]   # VMS
    assert_equal "0", extra[4]   # CTS
    assert_equal "-", extra[5]   # KERNEL
  end

  def test_extra_values_for_high_load_node
    extra = @presenter.extra_values(@high_load_node)

    # Load > 2.0 should show arrow indicator
    assert_equal "2.31\u2191", extra[0]   # LOAD with up arrow
  end

  # ---------------------------
  # to_wide_row() Method
  # ---------------------------

  def test_to_wide_row_combines_row_and_extra_values
    wide_row = @presenter.to_wide_row(@online_node)

    assert_equal 14, wide_row.length
    assert_equal "pve-node1", wide_row[0]     # NAME (first standard column)
    assert_equal "0.45", wide_row[7]          # LOAD (first extra column)
    assert_equal "6.8.12-1-pve", wide_row[12] # KERNEL
    assert_equal "-", wide_row[13]            # IP (last extra column, nil for node without IP)
  end

  # ---------------------------
  # to_hash() Method
  # ---------------------------

  def test_to_hash_returns_complete_node_data
    hash = @presenter.to_hash(@online_node)

    assert_equal "pve-node1", hash["name"]
    assert_equal "online", hash["status"]
    assert_equal "8.3.2", hash["version"]
    assert_equal "6.8.12-1-pve", hash["kernel"]
  end

  def test_to_hash_includes_cpu_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["cpu"]
    assert_equal 23, hash["cpu"]["usage_percent"]
    assert_equal 32, hash["cpu"]["cores"]
  end

  def test_to_hash_includes_memory_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["memory"]
    assert_equal 45.2, hash["memory"]["used_gb"]
    assert_equal 128, hash["memory"]["total_gb"]
    assert_equal 48_535_150_182, hash["memory"]["used_bytes"]
    assert_equal 137_438_953_472, hash["memory"]["total_bytes"]
    assert_in_delta 35.3, hash["memory"]["usage_percent"], 0.1
  end

  def test_to_hash_includes_swap_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["swap"]
    assert_equal 0, hash["swap"]["used_bytes"]
    assert_equal 8_589_934_592, hash["swap"]["total_bytes"]
    assert_equal 0.0, hash["swap"]["usage_percent"]
  end

  def test_to_hash_includes_storage_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["storage"]
    assert_equal 1_288_490_188_800, hash["storage"]["used_bytes"]
    assert_equal 4_398_046_511_104, hash["storage"]["total_bytes"]
    assert_in_delta 29.3, hash["storage"]["usage_percent"], 0.1
  end

  def test_to_hash_includes_load_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["load"]
    assert_equal 0.45, hash["load"]["avg1"]
    assert_equal 0.52, hash["load"]["avg5"]
    assert_equal 0.48, hash["load"]["avg15"]
  end

  def test_to_hash_includes_guests_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["guests"]
    assert_equal 42, hash["guests"]["total"]
    assert_equal 28, hash["guests"]["vms"]
    assert_equal 14, hash["guests"]["cts"]
  end

  def test_to_hash_includes_uptime_nested_structure
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["uptime"]
    assert_equal 3_898_800, hash["uptime"]["seconds"]
    assert_equal "45d 3h", hash["uptime"]["human"]
  end

  def test_to_hash_includes_alerts_array
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Array, hash["alerts"]
    assert_empty hash["alerts"]  # Healthy node has no alerts
  end

  def test_to_hash_for_offline_node_includes_offline_alert
    hash = @presenter.to_hash(@offline_node)

    assert_includes hash["alerts"], "Node offline"
  end

  def test_to_hash_for_offline_node_has_nil_cpu_percent
    hash = @presenter.to_hash(@offline_node)

    assert_nil hash["cpu"]["usage_percent"]
  end

  def test_to_hash_for_offline_node_has_nil_memory_percent
    hash = @presenter.to_hash(@offline_node)

    assert_nil hash["memory"]["usage_percent"]
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_to_row_accepts_context_kwargs
    row = @presenter.to_row(@online_node, current_context: "prod")
    assert_kind_of Array, row
  end

  def test_extra_values_accepts_context_kwargs
    extra = @presenter.extra_values(@online_node, highlight: true)
    assert_kind_of Array, extra
  end

  # ---------------------------
  # IP Column in Wide View
  # ---------------------------

  def test_extra_columns_includes_ip_as_last_column
    columns = @presenter.extra_columns
    assert_equal "IP", columns.last
  end

  def test_extra_values_includes_ip_for_online_node
    node_with_ip = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(ip: "192.168.1.10")
    )
    extra = @presenter.extra_values(node_with_ip)

    # IP is the last column
    assert_equal "192.168.1.10", extra.last
  end

  def test_extra_values_shows_dash_when_ip_nil
    extra = @presenter.extra_values(@online_node)

    assert_equal "-", extra.last
  end

  def test_extra_values_shows_dash_for_offline_node_ip
    extra = @presenter.extra_values(@offline_node)

    assert_equal "-", extra.last
  end

  def test_wide_columns_includes_ip_at_end
    columns = @presenter.wide_columns
    assert_equal "IP", columns.last
    assert_equal 14, columns.length  # 7 standard + 7 extra (with IP)
  end

  def test_to_wide_row_includes_ip_at_end
    node_with_ip = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(ip: "10.0.0.5")
    )
    wide_row = @presenter.to_wide_row(node_with_ip)

    assert_equal "10.0.0.5", wide_row.last
    assert_equal 14, wide_row.length
  end

  # ---------------------------
  # to_hash() with network.ip
  # ---------------------------

  def test_to_hash_includes_network_with_ip
    node_with_ip = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(ip: "192.168.1.10")
    )
    hash = @presenter.to_hash(node_with_ip)

    assert_kind_of Hash, hash["network"]
    assert_equal "192.168.1.10", hash["network"]["ip"]
  end

  def test_to_hash_network_ip_is_nil_when_not_available
    hash = @presenter.to_hash(@online_node)

    assert_kind_of Hash, hash["network"]
    assert_nil hash["network"]["ip"]
  end

  def test_to_hash_network_ip_is_nil_for_offline_node
    hash = @presenter.to_hash(@offline_node)

    assert_kind_of Hash, hash["network"]
    assert_nil hash["network"]["ip"]
  end

  # ---------------------------
  # to_description() Method
  # ---------------------------

  def test_to_description_returns_hash
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc
  end

  def test_to_description_includes_name
    desc = @presenter.to_description(@online_node)

    assert_equal "pve-node1", desc["Name"]
  end

  def test_to_description_includes_status
    desc = @presenter.to_description(@online_node)

    assert_equal "online", desc["Status"]
  end

  def test_to_description_includes_subscription
    node_with_subscription = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        subscription: { status: "Active", level: "c" }
      )
    )
    desc = @presenter.to_description(node_with_subscription)

    assert_equal "Active (Community)", desc["Subscription"]
  end

  def test_to_description_includes_system_section
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc["System"]
    assert_equal "8.3.2", desc["System"]["Version"]
    assert_equal "6.8.12-1-pve", desc["System"]["Kernel"]
    assert_equal "45d 3h", desc["System"]["Uptime"]
  end

  def test_to_description_includes_cpu_section
    node_with_cpuinfo = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        cpuinfo: { model: "AMD EPYC 7302", cores: 16, sockets: 2 }
      )
    )
    desc = @presenter.to_description(node_with_cpuinfo)

    assert_kind_of Hash, desc["CPU"]
    assert_equal "AMD EPYC 7302", desc["CPU"]["Model"]
    assert_equal 16, desc["CPU"]["Cores"]
    assert_equal 2, desc["CPU"]["Sockets"]
    assert_equal "23%", desc["CPU"]["Usage"]
  end

  def test_to_description_includes_memory_section
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc["Memory"]
    assert_includes desc["Memory"]["Used"], "GiB"
    assert_includes desc["Memory"]["Total"], "GiB"
  end

  def test_to_description_includes_swap_section
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc["Swap"]
    assert_includes desc["Swap"]["Used"], "GiB"
  end

  def test_to_description_includes_load_average_section
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc["Load Average"]
    assert_equal 0.45, desc["Load Average"]["1 min"]
    assert_equal 0.52, desc["Load Average"]["5 min"]
    assert_equal 0.48, desc["Load Average"]["15 min"]
  end

  def test_to_description_includes_dns_section
    node_with_dns = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        dns: { search: "example.com", dns1: "192.168.1.1", dns2: "8.8.8.8" }
      )
    )
    desc = @presenter.to_description(node_with_dns)

    assert_kind_of Hash, desc["DNS"]
    assert_equal "example.com", desc["DNS"]["Search"]
    assert_includes desc["DNS"]["Nameservers"], "192.168.1.1"
  end

  def test_to_description_includes_time_section
    node_with_time = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        time_info: { timezone: "Europe/Warsaw", localtime: 1705326765 }
      )
    )
    desc = @presenter.to_description(node_with_time)

    assert_kind_of Hash, desc["Time"]
    assert_equal "Europe/Warsaw", desc["Time"]["Timezone"]
    assert_match(/\d{4}-\d{2}-\d{2}/, desc["Time"]["Local Time"])
  end

  def test_to_description_includes_guests_section
    desc = @presenter.to_description(@online_node)

    assert_kind_of Hash, desc["Guests"]
    assert_equal 28, desc["Guests"]["VMs"]
    assert_equal 14, desc["Guests"]["Containers"]
    assert_equal 42, desc["Guests"]["Total"]
  end

  def test_to_description_includes_updates_section
    node_with_updates = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(updates_available: 5)
    )
    desc = @presenter.to_description(node_with_updates)

    assert_kind_of Hash, desc["Updates"]
    assert_equal "5 packages", desc["Updates"]["Available"]
  end

  def test_to_description_includes_alerts
    desc = @presenter.to_description(@online_node)

    assert_equal "-", desc["Alerts"]
  end

  def test_to_description_includes_alerts_for_offline_node
    desc = @presenter.to_description(@offline_node)

    # Offline node returns simplified description
    assert_equal "offline", desc["Status"]
  end

  def test_to_description_network_interfaces_as_array
    interfaces = [
      { iface: "vmbr0", type: "bridge", address: "192.168.1.10", gateway: "192.168.1.1" },
      { iface: "vmbr1", type: "bridge", address: "10.0.0.1", gateway: nil }
    ]
    node_with_network = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(network_interfaces: interfaces)
    )
    desc = @presenter.to_description(node_with_network)

    # Network Interfaces should be Array of Hashes (for table rendering)
    assert_kind_of Array, desc["Network Interfaces"]
    assert_equal 2, desc["Network Interfaces"].length
    assert_equal "vmbr0", desc["Network Interfaces"][0]["Name"]
  end

  def test_to_description_services_as_array
    services = [
      { service: "pve-cluster", state: "running", desc: "PVE Cluster" },
      { service: "pvedaemon", state: "running", desc: "PVE Daemon" }
    ]
    node_with_services = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(services: services)
    )
    desc = @presenter.to_description(node_with_services)

    # Services should be Array of Hashes (for table rendering)
    assert_kind_of Array, desc["Services"]
    assert_equal 2, desc["Services"].length
  end

  def test_to_description_storage_pools_as_array
    pools = [
      { storage: "local", type: "dir", total: 107_374_182_400, used: 53_687_091_200, avail: 53_687_091_200, enabled: 1 },
      { storage: "local-lvm", type: "lvmthin", total: 536_870_912_000, used: 268_435_456_000, avail: 268_435_456_000, enabled: 1 }
    ]
    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: pools)
    )
    desc = @presenter.to_description(node_with_storage)

    # Storage Pools should be Array of Hashes (for table rendering)
    assert_kind_of Array, desc["Storage Pools"]
    assert_equal 2, desc["Storage Pools"].length
    assert_equal "local", desc["Storage Pools"][0]["Name"]
  end

  def test_to_description_physical_disks_as_array
    disks = [
      { devpath: "/dev/sda", model: "Samsung SSD 870", size: 536_870_912_000, type: "SSD", health: "PASSED" }
    ]
    node_with_disks = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(physical_disks: disks)
    )
    desc = @presenter.to_description(node_with_disks)

    # Physical Disks should be Array of Hashes (for table rendering)
    assert_kind_of Array, desc["Physical Disks"]
    assert_equal "/dev/sda", desc["Physical Disks"][0]["Device"]
  end

  def test_to_description_capabilities_section
    node_with_caps = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        qemu_cpu_models: [{ name: "host" }, { name: "max" }, { name: "kvm64" }],
        qemu_machines: [{ id: "pc-q35-8.1" }, { id: "pc-i440fx-8.1" }]
      )
    )
    desc = @presenter.to_description(node_with_caps)

    assert_kind_of Hash, desc["Capabilities"]
    assert_includes desc["Capabilities"]["QEMU CPU Models"], "host"
    assert_includes desc["Capabilities"]["QEMU Machines"], "pc-q35-8.1"
  end

  def test_to_description_offline_node_minimal_output
    offline_with_note = Pvectl::Models::Node.new(
      @offline_node.instance_variable_get(:@attributes).merge(
        offline_note: "Node is offline. Detailed metrics unavailable."
      )
    )
    desc = @presenter.to_description(offline_with_note)

    # Offline node should have minimal structure
    assert_equal "pve-node4", desc["Name"]
    assert_equal "offline", desc["Status"]
    assert_equal "Node is offline. Detailed metrics unavailable.", desc["Note"]
  end

  # ===========================================================================
  # NEW TESTS FOR STORAGE-NODE-REFACTOR
  # Tests for format_storage_pools working with Array<Models::Storage>
  # ===========================================================================

  # ---------------------------
  # format_storage_pools() with Models::Storage
  # ---------------------------

  def test_to_description_storage_pools_with_storage_models
    # Create Storage models (new format after refactor)
    storage_models = [
      Pvectl::Models::Storage.new(
        name: "local",
        plugintype: "dir",
        maxdisk: 107_374_182_400,
        disk: 53_687_091_200,
        avail: 53_687_091_200,
        enabled: 1,
        active: 1,
        status: "available"
      ),
      Pvectl::Models::Storage.new(
        name: "local-lvm",
        plugintype: "lvmthin",
        maxdisk: 536_870_912_000,
        disk: 268_435_456_000,
        avail: 268_435_456_000,
        enabled: 1,
        active: 1,
        status: "available"
      )
    ]

    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: storage_models)
    )
    desc = @presenter.to_description(node_with_storage)

    # Storage Pools should be formatted correctly
    assert_kind_of Array, desc["Storage Pools"]
    assert_equal 2, desc["Storage Pools"].length
    assert_equal "local", desc["Storage Pools"][0]["Name"]
    assert_equal "dir", desc["Storage Pools"][0]["Type"]
  end

  def test_to_description_storage_pools_models_have_correct_columns
    storage_model = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      maxdisk: 107_374_182_400,
      disk: 53_687_091_200,
      avail: 53_687_091_200,
      enabled: 1,
      active: 1,
      status: "available"
    )

    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: [storage_model])
    )
    desc = @presenter.to_description(node_with_storage)

    pool = desc["Storage Pools"][0]
    assert_includes pool.keys, "Name"
    assert_includes pool.keys, "Type"
    assert_includes pool.keys, "Total"
    assert_includes pool.keys, "Used"
    assert_includes pool.keys, "Available"
    assert_includes pool.keys, "Usage"
  end

  def test_to_description_storage_pools_models_format_size_correctly
    storage_model = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      maxdisk: 107_374_182_400,    # 100 GB
      disk: 53_687_091_200,         # 50 GB
      avail: 53_687_091_200,        # 50 GB
      enabled: 1,
      active: 1,
      status: "available"
    )

    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: [storage_model])
    )
    desc = @presenter.to_description(node_with_storage)

    pool = desc["Storage Pools"][0]
    # After refactor, sizes should use Storage model's display methods
    assert_equal "100 GB", pool["Total"]
    assert_equal "50 GB", pool["Used"]
    assert_equal "50 GB", pool["Available"]
    assert_equal "50%", pool["Usage"]
  end

  def test_to_description_storage_pools_models_tb_format_for_large_storage
    storage_model = Pvectl::Models::Storage.new(
      name: "ceph-pool",
      plugintype: "rbd",
      maxdisk: 4_398_046_511_104,   # 4 TB
      disk: 2_199_023_255_552,       # 2 TB
      avail: 2_199_023_255_552,      # 2 TB
      enabled: 1,
      active: 1,
      status: "available"
    )

    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: [storage_model])
    )
    desc = @presenter.to_description(node_with_storage)

    pool = desc["Storage Pools"][0]
    assert_equal "4.0 TB", pool["Total"]
    assert_equal "2.0 TB", pool["Used"]
    assert_equal "2.0 TB", pool["Available"]
  end

  def test_to_description_storage_pools_filters_disabled_models
    enabled_storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      maxdisk: 107_374_182_400,
      disk: 53_687_091_200,
      avail: 53_687_091_200,
      enabled: 1,
      active: 1,
      status: "available"
    )
    disabled_storage = Pvectl::Models::Storage.new(
      name: "backup-disabled",
      plugintype: "nfs",
      maxdisk: 0,
      disk: 0,
      avail: 0,
      enabled: 0,
      active: 0,
      status: "unavailable"
    )

    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(
        storage_pools: [enabled_storage, disabled_storage]
      )
    )
    desc = @presenter.to_description(node_with_storage)

    # Only enabled storage should appear
    assert_equal 1, desc["Storage Pools"].length
    assert_equal "local", desc["Storage Pools"][0]["Name"]
  end

  def test_to_description_storage_pools_empty_array_returns_dash
    node_with_empty_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: [])
    )
    desc = @presenter.to_description(node_with_empty_storage)

    assert_equal "-", desc["Storage Pools"]
  end

  def test_to_description_storage_pools_nil_returns_dash
    node_with_nil_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: nil)
    )
    desc = @presenter.to_description(node_with_nil_storage)

    assert_equal "-", desc["Storage Pools"]
  end

  # ---------------------------
  # Backward Compatibility with Hash Format
  # During transition, both formats should work
  # ---------------------------

  def test_to_description_storage_pools_still_works_with_hash_format
    # Original Hash format (before refactor)
    pools = [
      { storage: "local", type: "dir", total: 107_374_182_400, used: 53_687_091_200, avail: 53_687_091_200, enabled: 1 }
    ]
    node_with_storage = Pvectl::Models::Node.new(
      @online_node.instance_variable_get(:@attributes).merge(storage_pools: pools)
    )
    desc = @presenter.to_description(node_with_storage)

    # Hash format should still work
    assert_kind_of Array, desc["Storage Pools"]
    assert_equal "local", desc["Storage Pools"][0]["Name"]
  end

  # ===========================================================================
  # DISPLAY METHOD TESTS (moved from Models::Node)
  # ===========================================================================

  # ---------------------------
  # CPU Percent Method
  # ---------------------------

  def test_cpu_percent_for_online_node
    @presenter.to_row(@online_node) # sets @node
    assert_equal "23%", @presenter.cpu_percent
  end

  def test_cpu_percent_for_offline_node
    @presenter.to_row(@offline_node) # sets @node
    assert_equal "-", @presenter.cpu_percent
  end

  def test_cpu_percent_with_nil_cpu
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: nil))
    @presenter.to_row(node)
    assert_equal "-", @presenter.cpu_percent
  end

  def test_cpu_percent_rounds_value
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: 0.456))
    @presenter.to_row(node)
    assert_equal "46%", @presenter.cpu_percent
  end

  # ---------------------------
  # Memory Methods
  # ---------------------------

  def test_memory_used_gb_for_online_node
    @presenter.to_row(@online_node)
    assert_equal 45.2, @presenter.memory_used_gb
  end

  def test_memory_used_gb_returns_nil_when_mem_nil
    @presenter.to_row(@offline_node)
    assert_nil @presenter.memory_used_gb
  end

  def test_memory_total_gb
    @presenter.to_row(@online_node)
    assert_equal 128, @presenter.memory_total_gb
  end

  def test_memory_total_gb_returns_nil_when_maxmem_nil
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(maxmem: nil))
    @presenter.to_row(node)
    assert_nil @presenter.memory_total_gb
  end

  def test_memory_display_for_online_node
    @presenter.to_row(@online_node)
    assert_equal "45.2/128 GB", @presenter.memory_display
  end

  def test_memory_display_for_offline_node
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.memory_display
  end

  def test_memory_display_with_nil_maxmem
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(maxmem: nil))
    @presenter.to_row(node)
    assert_equal "-", @presenter.memory_display
  end

  # ---------------------------
  # Storage Methods
  # ---------------------------

  def test_disk_used_gb
    @presenter.to_row(@online_node)
    assert_equal 1200.0, @presenter.disk_used_gb
  end

  def test_disk_used_gb_returns_nil_when_disk_nil
    @presenter.to_row(@offline_node)
    assert_nil @presenter.disk_used_gb
  end

  def test_disk_total_gb
    @presenter.to_row(@online_node)
    assert_equal 4096.0, @presenter.disk_total_gb
  end

  def test_disk_total_gb_returns_nil_when_maxdisk_nil
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(maxdisk: nil))
    @presenter.to_row(node)
    assert_nil @presenter.disk_total_gb
  end

  def test_storage_display
    @presenter.to_row(@online_node)
    assert_equal "1.2/4.0 TB", @presenter.storage_display
  end

  def test_storage_display_for_offline_node
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.storage_display
  end

  def test_storage_display_uses_gb_for_small_disks
    # 85 GB used, 100 GB total (under 1 TB threshold)
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      disk: 91_268_055_040,    # 85 GB
      maxdisk: 107_374_182_400 # 100 GB
    ))
    @presenter.to_row(node)
    assert_equal "85/100 GB", @presenter.storage_display
  end

  # ---------------------------
  # Swap Methods
  # ---------------------------

  def test_swap_used_gb
    @presenter.to_row(@online_node)
    assert_equal 0.0, @presenter.swap_used_gb
  end

  def test_swap_total_gb
    @presenter.to_row(@online_node)
    assert_equal 8, @presenter.swap_total_gb
  end

  def test_swap_display
    @presenter.to_row(@online_node)
    assert_equal "0.0/8 GB", @presenter.swap_display
  end

  def test_swap_display_for_offline_node
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.swap_display
  end

  # ---------------------------
  # Load Average Methods
  # ---------------------------

  def test_load_1m
    @presenter.to_row(@online_node)
    assert_equal 0.45, @presenter.load_1m
  end

  def test_load_1m_returns_nil_when_loadavg_nil
    @presenter.to_row(@offline_node)
    assert_nil @presenter.load_1m
  end

  def test_load_1m_returns_nil_when_loadavg_empty
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(loadavg: []))
    @presenter.to_row(node)
    assert_nil @presenter.load_1m
  end

  def test_load_display
    @presenter.to_row(@online_node)
    assert_equal "0.45", @presenter.load_display
  end

  def test_load_display_with_high_load_indicator
    @presenter.to_row(@high_load_node)
    assert_equal "2.31\u2191", @presenter.load_display  # 2.31 with up arrow
  end

  def test_load_display_for_offline_node
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.load_display
  end

  # ---------------------------
  # Uptime Methods
  # ---------------------------

  def test_uptime_human_for_days_and_hours
    @presenter.to_row(@online_node)
    assert_equal "45d 3h", @presenter.uptime_human
  end

  def test_uptime_human_for_hours_and_minutes
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(uptime: 8100))  # 2h 15m
    @presenter.to_row(node)
    assert_equal "2h 15m", @presenter.uptime_human
  end

  def test_uptime_human_for_minutes_only
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(uptime: 900))  # 15m
    @presenter.to_row(node)
    assert_equal "15m", @presenter.uptime_human
  end

  def test_uptime_human_returns_dash_for_offline_node
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.uptime_human
  end

  def test_uptime_human_returns_dash_when_zero
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(uptime: 0))
    @presenter.to_row(node)
    assert_equal "-", @presenter.uptime_human
  end

  # ---------------------------
  # Version and Kernel Display
  # ---------------------------

  def test_version_display
    @presenter.to_row(@online_node)
    assert_equal "8.3.2", @presenter.version_display
  end

  def test_version_display_returns_dash_when_nil
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.version_display
  end

  def test_kernel_display
    @presenter.to_row(@online_node)
    assert_equal "6.8.12-1-pve", @presenter.kernel_display
  end

  def test_kernel_display_returns_dash_when_nil
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.kernel_display
  end

  # ---------------------------
  # IP Display
  # ---------------------------

  def test_ip_display_returns_ip_when_available
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(ip: "192.168.1.10"))
    @presenter.to_row(node)
    assert_equal "192.168.1.10", @presenter.ip_display
  end

  def test_ip_display_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.ip_display
  end

  def test_ip_display_for_offline_node_without_ip
    @presenter.to_row(@offline_node)
    assert_equal "-", @presenter.ip_display
  end

  # ---------------------------
  # Alerts Methods
  # ---------------------------

  def test_alerts_returns_empty_array_for_healthy_node
    @presenter.to_row(@online_node)
    assert_empty @presenter.alerts
  end

  def test_alerts_includes_offline_message
    @presenter.to_row(@offline_node)
    assert_includes @presenter.alerts, "Node offline"
  end

  def test_alerts_includes_cpu_critical
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: 0.92))
    @presenter.to_row(node)
    assert @presenter.alerts.any? { |a| a.include?("CPU critical") }
  end

  def test_alerts_includes_cpu_warning
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: 0.85))
    @presenter.to_row(node)
    assert @presenter.alerts.any? { |a| a.include?("CPU warning") }
  end

  def test_alerts_no_cpu_alert_below_80
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: 0.79))
    @presenter.to_row(node)
    refute @presenter.alerts.any? { |a| a.include?("CPU") }
  end

  def test_alerts_includes_memory_critical
    # Set memory to 92% usage
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      mem: (0.92 * 137_438_953_472).to_i
    ))
    @presenter.to_row(node)
    assert @presenter.alerts.any? { |a| a.include?("Memory critical") }
  end

  def test_alerts_includes_memory_warning
    # Set memory to 85% usage
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      mem: (0.85 * 137_438_953_472).to_i
    ))
    @presenter.to_row(node)
    assert @presenter.alerts.any? { |a| a.include?("Memory warning") }
  end

  def test_alerts_display_joins_alerts
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(cpu: 0.92))
    @presenter.to_row(node)
    refute_equal "-", @presenter.alerts_display
    assert @presenter.alerts_display.include?("CPU critical")
  end

  def test_alerts_display_returns_dash_when_no_alerts
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.alerts_display
  end

  def test_has_alerts_returns_true_when_alerts_exist
    @presenter.to_row(@offline_node)
    assert @presenter.has_alerts?
  end

  def test_has_alerts_returns_false_when_no_alerts
    @presenter.to_row(@online_node)
    refute @presenter.has_alerts?
  end

  # ---------------------------
  # Extended Helper Methods for Describe
  # ---------------------------

  def test_cpu_model_returns_model_from_cpuinfo
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      cpuinfo: { model: "AMD EPYC 7302 16-Core" }
    ))
    @presenter.to_row(node)
    assert_equal "AMD EPYC 7302 16-Core", @presenter.cpu_model
  end

  def test_cpu_model_returns_nil_when_cpuinfo_nil
    @presenter.to_row(@online_node)
    assert_nil @presenter.cpu_model
  end

  def test_cpu_sockets_returns_sockets_from_cpuinfo
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      cpuinfo: { sockets: 2 }
    ))
    @presenter.to_row(node)
    assert_equal 2, @presenter.cpu_sockets
  end

  def test_cpu_cores_returns_cores_from_cpuinfo
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      cpuinfo: { cores: 16 }
    ))
    @presenter.to_row(node)
    assert_equal 16, @presenter.cpu_cores
  end

  def test_boot_mode_returns_uefi_for_efi
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      boot_info: { mode: "efi" }
    ))
    @presenter.to_row(node)
    assert_equal "UEFI", @presenter.boot_mode
  end

  def test_boot_mode_returns_bios_for_bios
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      boot_info: { mode: "bios" }
    ))
    @presenter.to_row(node)
    assert_equal "BIOS", @presenter.boot_mode
  end

  def test_boot_mode_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.boot_mode
  end

  def test_subscription_display_active_community
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      subscription: { status: "Active", level: "c" }
    ))
    @presenter.to_row(node)
    assert_equal "Active (Community)", @presenter.subscription_display
  end

  def test_subscription_display_active_basic
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      subscription: { status: "Active", level: "b" }
    ))
    @presenter.to_row(node)
    assert_equal "Active (Basic)", @presenter.subscription_display
  end

  def test_subscription_display_active_standard
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      subscription: { status: "Active", level: "s" }
    ))
    @presenter.to_row(node)
    assert_equal "Active (Standard)", @presenter.subscription_display
  end

  def test_subscription_display_active_premium
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      subscription: { status: "Active", level: "p" }
    ))
    @presenter.to_row(node)
    assert_equal "Active (Premium)", @presenter.subscription_display
  end

  def test_subscription_display_inactive
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      subscription: { status: "Inactive", level: nil }
    ))
    @presenter.to_row(node)
    assert_equal "Inactive", @presenter.subscription_display
  end

  def test_subscription_display_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.subscription_display
  end

  def test_timezone_returns_timezone_from_time_info
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      time_info: { timezone: "Europe/Warsaw" }
    ))
    @presenter.to_row(node)
    assert_equal "Europe/Warsaw", @presenter.timezone
  end

  def test_timezone_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.timezone
  end

  def test_local_time_returns_formatted_time
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      time_info: { localtime: 1705326765 }
    ))
    @presenter.to_row(node)
    # Format depends on system timezone, but should match pattern
    assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, @presenter.local_time)
  end

  def test_local_time_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.local_time
  end

  def test_dns_search_returns_search_domain
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      dns: { search: "example.com" }
    ))
    @presenter.to_row(node)
    assert_equal "example.com", @presenter.dns_search
  end

  def test_dns_search_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.dns_search
  end

  def test_dns_nameservers_returns_comma_separated_list
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      dns: { dns1: "192.168.1.1", dns2: "8.8.8.8", dns3: "8.8.4.4" }
    ))
    @presenter.to_row(node)
    assert_equal "192.168.1.1, 8.8.8.8, 8.8.4.4", @presenter.dns_nameservers
  end

  def test_dns_nameservers_filters_nil_values
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      dns: { dns1: "192.168.1.1", dns2: nil, dns3: nil }
    ))
    @presenter.to_row(node)
    assert_equal "192.168.1.1", @presenter.dns_nameservers
  end

  def test_dns_nameservers_returns_dash_when_empty
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.dns_nameservers
  end

  def test_rootfs_usage_percent
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      rootfs: { used: 1_288_490_188_800, total: 4_398_046_511_104 }
    ))
    @presenter.to_row(node)
    assert_equal 29, @presenter.rootfs_usage_percent
  end

  def test_rootfs_usage_percent_returns_nil_when_nil
    @presenter.to_row(@online_node)
    assert_nil @presenter.rootfs_usage_percent
  end

  def test_rootfs_display_with_large_disk
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      rootfs: { used: 1_288_490_188_800, total: 4_398_046_511_104 }
    ))
    @presenter.to_row(node)
    # ~1.2 TB used, ~4.0 TB total = 29%
    assert_match(/29%.*1\.2.*4\.0.*TiB/, @presenter.rootfs_display)
  end

  def test_rootfs_display_with_small_disk
    node = Pvectl::Models::Node.new(@online_node.instance_variable_get(:@attributes).merge(
      rootfs: { used: 53_687_091_200, total: 107_374_182_400 }
    ))
    @presenter.to_row(node)
    # ~50 GB used, ~100 GB total = 50%
    assert_match(/50%.*GiB/, @presenter.rootfs_display)
  end

  def test_rootfs_display_returns_dash_when_nil
    @presenter.to_row(@online_node)
    assert_equal "-", @presenter.rootfs_display
  end
end
