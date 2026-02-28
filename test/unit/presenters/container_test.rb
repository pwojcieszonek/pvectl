# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Container Tests
# =============================================================================

class PresentersContainerTest < Minitest::Test
  # Tests for the Container presenter

  def setup
    @running_container = Pvectl::Models::Container.new(
      vmid: 200,
      name: "web-container",
      status: "running",
      node: "pve1",
      cpu: 0.05,
      maxcpu: 2,
      mem: 1_288_490_189,              # 1.2 GiB
      maxmem: 2_147_483_648,           # 2.0 GiB
      swap: 0,
      maxswap: 536_870_912,            # 512 MiB
      disk: 3_435_973_837,             # 3.2 GiB
      maxdisk: 8_589_934_592,          # 8 GiB
      uptime: 439_200,                 # 5d 2h
      template: 0,
      tags: "prod;web",
      pool: "production",
      netin: 123_456_789,
      netout: 987_654_321
    )

    @stopped_container = Pvectl::Models::Container.new(
      vmid: 201,
      name: "dev-container",
      status: "stopped",
      node: "pve2",
      cpu: nil,
      maxcpu: 1,
      mem: nil,
      maxmem: 1_073_741_824,           # 1.0 GiB
      swap: nil,
      maxswap: 268_435_456,            # 256 MiB
      disk: 1_073_741_824,             # 1 GiB
      maxdisk: 4_294_967_296,          # 4 GiB
      uptime: nil,
      template: 0,
      tags: "dev",
      pool: nil,
      netin: nil,
      netout: nil
    )

    @template_container = Pvectl::Models::Container.new(
      vmid: 9000,
      name: "debian-template",
      status: "stopped",
      node: "pve1",
      cpu: nil,
      maxcpu: 1,
      mem: nil,
      maxmem: 536_870_912,
      swap: nil,
      maxswap: 0,
      disk: 536_870_912,
      maxdisk: 2_147_483_648,
      uptime: nil,
      template: 1,
      tags: nil,
      pool: nil,
      netin: nil,
      netout: nil
    )

    @presenter = Pvectl::Presenters::Container.new
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_container_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::Container
  end

  def test_container_presenter_inherits_from_base
    assert Pvectl::Presenters::Container < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns() Method
  # ---------------------------

  def test_columns_returns_expected_headers
    expected = %w[NAME CTID STATUS NODE CPU MEMORY]
    assert_equal expected, @presenter.columns
  end

  # ---------------------------
  # extra_columns() Method
  # ---------------------------

  def test_extra_columns_returns_wide_headers
    expected = %w[UPTIME TEMPLATE TAGS SWAP DISK NETIN NETOUT POOL]
    assert_equal expected, @presenter.extra_columns
  end

  # ---------------------------
  # wide_columns() Method
  # ---------------------------

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[NAME CTID STATUS NODE CPU MEMORY UPTIME TEMPLATE TAGS SWAP DISK NETIN NETOUT POOL]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row() Method - Running Container
  # ---------------------------

  def test_to_row_for_running_container
    row = @presenter.to_row(@running_container)

    assert_equal 6, row.length
    assert_equal "web-container", row[0]  # NAME
    assert_equal "200", row[1]            # CTID
    assert_equal "running", row[2]        # STATUS
    assert_equal "pve1", row[3]           # NODE
    assert_equal "5%/2", row[4]           # CPU
    assert_equal "1.2/2.0 GiB", row[5]   # MEMORY
  end

  # ---------------------------
  # to_row() Method - Stopped Container
  # ---------------------------

  def test_to_row_for_stopped_container
    row = @presenter.to_row(@stopped_container)

    assert_equal 6, row.length
    assert_equal "dev-container", row[0]  # NAME
    assert_equal "201", row[1]            # CTID
    assert_equal "stopped", row[2]        # STATUS
    assert_equal "pve2", row[3]           # NODE
    assert_equal "-/1", row[4]            # CPU
    assert_equal "-/1.0 GiB", row[5]      # MEMORY
  end

  # ---------------------------
  # to_row() Method - Template
  # ---------------------------

  def test_to_row_for_template
    row = @presenter.to_row(@template_container)

    assert_equal 6, row.length
    assert_equal "debian-template", row[0] # NAME
    assert_equal "9000", row[1]            # CTID
    assert_equal "stopped", row[2]         # STATUS
    assert_equal "pve1", row[3]            # NODE
    assert_equal "-/1", row[4]             # CPU
    assert_equal "-/0.5 GiB", row[5]       # MEMORY
  end

  # ---------------------------
  # extra_values() Method
  # ---------------------------

  def test_extra_values_for_running_container
    extra = @presenter.extra_values(@running_container)

    assert_equal 8, extra.length
    assert_equal "5d 2h", extra[0]        # UPTIME
    assert_equal "-", extra[1]             # TEMPLATE
    assert_equal "prod, web", extra[2]     # TAGS
    assert_equal "0/512 MiB", extra[3]     # SWAP
    assert_equal "3.2/8.0 GiB", extra[4]  # DISK
    assert_match(/MiB$/, extra[5])         # NETIN
    assert_match(/MiB$/, extra[6])         # NETOUT
    assert_equal "production", extra[7]    # POOL
  end

  def test_extra_values_for_stopped_container
    extra = @presenter.extra_values(@stopped_container)

    assert_equal 8, extra.length
    assert_equal "-", extra[0]             # UPTIME
    assert_equal "-", extra[1]             # TEMPLATE
    assert_equal "dev", extra[2]           # TAGS
    assert_equal "-/256 MiB", extra[3]     # SWAP
    assert_equal "1.0/4.0 GiB", extra[4]  # DISK
    assert_equal "-", extra[5]             # NETIN
    assert_equal "-", extra[6]             # NETOUT
    assert_equal "-", extra[7]             # POOL
  end

  # ---------------------------
  # to_wide_row() Method
  # ---------------------------

  def test_to_wide_row_combines_row_and_extra_values
    wide_row = @presenter.to_wide_row(@running_container)

    assert_equal 14, wide_row.length
    assert_equal "web-container", wide_row[0]  # NAME
    assert_equal "200", wide_row[1]            # CTID
    assert_equal "5d 2h", wide_row[6]          # UPTIME (first extra)
    assert_equal "production", wide_row[13]    # POOL
  end

  # ---------------------------
  # to_hash() Method
  # ---------------------------

  def test_to_hash_returns_complete_container_data
    hash = @presenter.to_hash(@running_container)

    assert_equal 200, hash["ctid"]
    assert_equal "web-container", hash["name"]
    assert_equal "running", hash["status"]
    assert_equal "pve1", hash["node"]
    refute hash["template"]
  end

  def test_to_hash_includes_cpu_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["cpu"]
    assert_equal 5, hash["cpu"]["usage_percent"]
    assert_equal 2, hash["cpu"]["cores"]
  end

  def test_to_hash_includes_memory_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["memory"]
    assert_equal 1.2, hash["memory"]["used_gib"]
    assert_equal 2.0, hash["memory"]["total_gib"]
    assert_equal 1_288_490_189, hash["memory"]["used_bytes"]
    assert_equal 2_147_483_648, hash["memory"]["total_bytes"]
  end

  def test_to_hash_includes_swap_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["swap"]
    assert_equal 0.0, hash["swap"]["used_mib"]
    assert_equal 512.0, hash["swap"]["total_mib"]
    assert_equal 0, hash["swap"]["used_bytes"]
    assert_equal 536_870_912, hash["swap"]["total_bytes"]
  end

  def test_to_hash_includes_disk_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["disk"]
    assert_equal 3.2, hash["disk"]["used_gib"]
    assert_equal 8.0, hash["disk"]["total_gib"]
    assert_equal 3_435_973_837, hash["disk"]["used_bytes"]
    assert_equal 8_589_934_592, hash["disk"]["total_bytes"]
  end

  def test_to_hash_includes_uptime_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["uptime"]
    assert_equal 439_200, hash["uptime"]["seconds"]
    assert_equal "5d 2h", hash["uptime"]["human"]
  end

  def test_to_hash_includes_network_nested_structure
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Hash, hash["network"]
    assert_equal 123_456_789, hash["network"]["in_bytes"]
    assert_equal 987_654_321, hash["network"]["out_bytes"]
  end

  def test_to_hash_includes_tags_as_array
    hash = @presenter.to_hash(@running_container)

    assert_kind_of Array, hash["tags"]
    assert_equal ["prod", "web"], hash["tags"]
  end

  def test_to_hash_includes_pool
    hash = @presenter.to_hash(@running_container)
    assert_equal "production", hash["pool"]

    hash_stopped = @presenter.to_hash(@stopped_container)
    assert_nil hash_stopped["pool"]
  end

  def test_to_hash_template_flag_is_boolean
    hash = @presenter.to_hash(@template_container)
    assert_equal true, hash["template"]

    hash = @presenter.to_hash(@running_container)
    assert_equal false, hash["template"]
  end

  def test_to_hash_for_stopped_container_has_nil_cpu_percent
    hash = @presenter.to_hash(@stopped_container)

    assert_nil hash["cpu"]["usage_percent"]
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_to_row_accepts_context_kwargs
    row = @presenter.to_row(@running_container, current_context: "prod")
    assert_kind_of Array, row
  end

  def test_extra_values_accepts_context_kwargs
    extra = @presenter.extra_values(@running_container, highlight: true)
    assert_kind_of Array, extra
  end

  # ---------------------------
  # Display Methods
  # ---------------------------

  def test_display_name_returns_name_when_present
    @presenter.to_row(@running_container)
    assert_equal "web-container", @presenter.display_name
  end

  def test_display_name_returns_fallback_when_name_nil
    ct = Pvectl::Models::Container.new(vmid: 100, name: nil, status: "running", node: "pve1")
    @presenter.to_row(ct)
    assert_equal "CT-100", @presenter.display_name
  end

  def test_cpu_percent_for_running_container
    @presenter.to_row(@running_container)
    assert_equal "5%/2", @presenter.cpu_percent
  end

  def test_cpu_percent_for_stopped_container
    @presenter.to_row(@stopped_container)
    assert_equal "-/1", @presenter.cpu_percent
  end

  def test_cpu_percent_with_nil_cpu
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: nil, maxcpu: 4
    )
    @presenter.to_row(ct)
    assert_equal "-/4", @presenter.cpu_percent
  end

  def test_cpu_percent_rounds_value
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: 0.456, maxcpu: 4
    )
    @presenter.to_row(ct)
    assert_equal "46%/4", @presenter.cpu_percent
  end

  def test_cpu_percent_with_nil_maxcpu
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: 0.12, maxcpu: nil
    )
    @presenter.to_row(ct)
    assert_equal "-", @presenter.cpu_percent
  end

  def test_memory_used_gib_for_running_container
    @presenter.to_row(@running_container)
    assert_equal 1.2, @presenter.memory_used_gib
  end

  def test_memory_used_gib_returns_nil_when_mem_nil
    @presenter.to_row(@stopped_container)
    assert_nil @presenter.memory_used_gib
  end

  def test_memory_total_gib
    @presenter.to_row(@running_container)
    assert_equal 2.0, @presenter.memory_total_gib
  end

  def test_memory_total_gib_returns_nil_when_maxmem_nil
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      mem: 2_254_857_830, maxmem: nil
    )
    @presenter.to_row(ct)
    assert_nil @presenter.memory_total_gib
  end

  def test_memory_display_for_running_container
    @presenter.to_row(@running_container)
    assert_equal "1.2/2.0 GiB", @presenter.memory_display
  end

  def test_memory_display_for_stopped_container
    @presenter.to_row(@stopped_container)
    assert_equal "-/1.0 GiB", @presenter.memory_display
  end

  def test_memory_display_with_nil_maxmem
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      mem: 2_254_857_830, maxmem: nil
    )
    @presenter.to_row(ct)
    assert_equal "-", @presenter.memory_display
  end

  def test_swap_display_for_running_container
    @presenter.to_row(@running_container)
    assert_equal "0/512 MiB", @presenter.swap_display
  end

  def test_swap_display_for_stopped_container
    @presenter.to_row(@stopped_container)
    assert_equal "-/256 MiB", @presenter.swap_display
  end

  def test_disk_used_gib
    @presenter.to_row(@running_container)
    assert_equal 3.2, @presenter.disk_used_gib
  end

  def test_disk_used_gib_returns_nil_when_disk_nil
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: nil, maxdisk: 53_687_091_200
    )
    @presenter.to_row(ct)
    assert_nil @presenter.disk_used_gib
  end

  def test_disk_total_gib
    @presenter.to_row(@running_container)
    assert_equal 8.0, @presenter.disk_total_gib
  end

  def test_disk_total_gib_returns_nil_when_maxdisk_nil
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: 16_106_127_360, maxdisk: nil
    )
    @presenter.to_row(ct)
    assert_nil @presenter.disk_total_gib
  end

  def test_disk_display
    @presenter.to_row(@running_container)
    assert_equal "3.2/8.0 GiB", @presenter.disk_display
  end

  def test_disk_display_returns_dash_when_disk_nil
    ct = Pvectl::Models::Container.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: nil, maxdisk: 53_687_091_200
    )
    @presenter.to_row(ct)
    assert_equal "-", @presenter.disk_display
  end

  # ---------------------------
  # to_description() Method
  # ---------------------------

  def test_to_description_returns_hash
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc
  end

  def test_to_description_includes_basic_fields
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_equal "web-container", desc["Name"]
    assert_equal 200, desc["CTID"]
    assert_equal "running", desc["Status"]
    assert_equal "pve1", desc["Node"]
    assert_equal "no", desc["Template"]
  end

  def test_to_description_includes_system_section
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["System"]
    assert_equal "debian", desc["System"]["OS Type"]
    assert_equal "amd64", desc["System"]["Architecture"]
    assert_equal "yes", desc["System"]["Unprivileged"]
  end

  def test_to_description_includes_cpu_section
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["CPU"]
    assert_equal 2, desc["CPU"]["Cores"]
    assert_equal "5%", desc["CPU"]["Usage"]
  end

  def test_to_description_includes_memory_section
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["Memory"]
    assert_includes desc["Memory"]["Total"], "GiB"
    assert_includes desc["Memory"]["Used"], "GiB"
    assert_includes desc["Memory"]["Usage"], "%"
  end

  def test_to_description_includes_swap_section
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["Swap"]
    assert_includes desc["Swap"]["Total"], "MiB"
    assert_includes desc["Swap"]["Used"], "MiB"
  end

  def test_to_description_includes_root_filesystem_section
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["Root Filesystem"]
    assert_includes desc["Root Filesystem"]["Size"], "GiB"
    assert_includes desc["Root Filesystem"]["Used"], "GiB"
  end

  def test_to_description_includes_network_interfaces_table
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Array, desc["Network"]
    assert desc["Network"].any? { |n| n["NAME"] == "eth0" }

    net = desc["Network"].find { |n| n["NAME"] == "eth0" }
    assert_equal "vmbr0", net["BRIDGE"]
    assert_equal "192.168.1.50/24", net["IP"]
  end

  def test_to_description_includes_features
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_equal "nesting, keyctl", desc["Features"]
  end

  def test_to_description_includes_runtime_for_running_container
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_kind_of Hash, desc["Runtime"]
    assert_equal "5d 2h", desc["Runtime"]["Uptime"]
    assert_equal 54321, desc["Runtime"]["PID"]
  end

  def test_to_description_stopped_container_runtime_shows_dash
    ct_with_describe_data = create_container_with_describe_data(@stopped_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_equal "-", desc["Runtime"]
  end

  def test_to_description_includes_tags
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_equal "prod, web", desc["Tags"]
  end

  def test_to_description_includes_description
    ct_with_describe_data = create_container_with_describe_data(@running_container)
    desc = @presenter.to_description(ct_with_describe_data)

    assert_equal "Production web container", desc["Description"]
  end

  def test_to_description_with_minimal_container
    desc = @presenter.to_description(@running_container)

    # Should handle container without describe attributes gracefully
    assert_kind_of Hash, desc
    assert_equal "web-container", desc["Name"]
  end

  # ---------------------------
  # to_description() — Pool field
  # ---------------------------

  def test_to_description_includes_pool
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)
    assert desc.key?("Pool")
  end

  # ---------------------------
  # to_description() — Catch-all mechanism
  # ---------------------------

  def test_to_description_catch_all_shows_unknown_keys
    ct = create_ct_from_data(some_future_key: "future_value", another_unknown: "42")
    desc = @presenter.to_description(ct)

    assert desc.key?("Additional Configuration")
    additional = desc["Additional Configuration"]
    assert_kind_of Array, additional
    keys = additional.map { |row| row["KEY"] }
    assert_includes keys, "some_future_key"
    assert_includes keys, "another_unknown"
  end

  def test_to_description_catch_all_excludes_digest
    ct = create_ct_from_data(digest: "abc123def456")
    desc = @presenter.to_description(ct)

    additional = desc["Additional Configuration"]
    if additional.is_a?(Array)
      keys = additional.map { |row| row["KEY"] }
      refute_includes keys, "digest"
    end
  end

  def test_to_description_catch_all_dash_when_all_consumed
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["Additional Configuration"]
  end

  # ---------------------------
  # to_description() — Mountpoints section
  # ---------------------------

  def test_to_description_includes_mountpoints
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(
          mp0: "local-lvm:vm-200-disk-1,mp=/mnt/data,size=50G",
          mp1: "local-lvm:vm-200-disk-2,mp=/mnt/backup,size=100G,ro=1"
        ),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Array, desc["Mountpoints"]
    assert_equal 2, desc["Mountpoints"].length
    assert_equal "/mnt/data", desc["Mountpoints"].first["PATH"]
  end

  def test_to_description_mountpoints_dash_when_none
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["Mountpoints"]
  end

  # ---------------------------
  # to_description() — DNS section
  # ---------------------------

  def test_to_description_includes_dns
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(nameserver: "8.8.8.8 1.1.1.1", searchdomain: "example.com"),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["DNS"]
    assert_equal "8.8.8.8 1.1.1.1", desc["DNS"]["Nameserver"]
    assert_equal "example.com", desc["DNS"]["Search Domain"]
  end

  def test_to_description_dns_dash_when_not_configured
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["DNS"]
  end

  # ---------------------------
  # to_description() — Console section
  # ---------------------------

  def test_to_description_includes_console
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(cmode: "console", tty: 2),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["Console"]
    assert_equal "console", desc["Console"]["Mode"]
    assert_equal 2, desc["Console"]["TTY"]
  end

  def test_to_description_console_dash_when_not_configured
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["Console"]
  end

  # ---------------------------
  # to_description() — Snapshots section
  # ---------------------------

  def test_to_description_includes_snapshots
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config,
        status: { pid: 54321 },
        snapshots: [
          { name: "baseline", snaptime: 1705240365, description: "Initial setup" }
        ]
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Array, desc["Snapshots"]
    assert_equal "baseline", desc["Snapshots"].first["NAME"]
    assert_includes desc["Snapshots"].first["DATE"], "2024"
    assert_equal "Initial setup", desc["Snapshots"].first["DESCRIPTION"]
  end

  def test_to_description_snapshots_no_snapshots
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config,
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_equal "No snapshots", desc["Snapshots"]
  end

  # ---------------------------
  # to_description() — Startup/Shutdown section
  # ---------------------------

  def test_to_description_includes_startup
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(startup: "order=1,up=30,down=60", onboot: 1),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["Startup/Shutdown"]
    assert_equal "1", desc["Startup/Shutdown"]["Order"]
    assert_equal "30", desc["Startup/Shutdown"]["Up Delay"]
    assert_equal "60", desc["Startup/Shutdown"]["Down Delay"]
    assert_equal "yes", desc["Startup/Shutdown"]["On Boot"]
  end

  def test_to_description_startup_defaults_when_not_configured
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["Startup/Shutdown"]
    assert_equal "-", desc["Startup/Shutdown"]["Order"]
    assert_equal "no", desc["Startup/Shutdown"]["On Boot"]
  end

  # ---------------------------
  # to_description() — Security section
  # ---------------------------

  def test_to_description_includes_security
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(protection: 1),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["Security"]
    assert_equal "yes", desc["Security"]["Protection"]
  end

  def test_to_description_security_defaults
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["Security"]
    assert_equal "no", desc["Security"]["Protection"]
    assert_equal "-", desc["Security"]["Lock"]
  end

  # ---------------------------
  # to_description() — Hookscript section
  # ---------------------------

  def test_to_description_includes_hookscript
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config.merge(hookscript: "local:snippets/hook.sh"),
        status: { pid: 54321 },
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_equal "local:snippets/hook.sh", desc["Hookscript"]
  end

  def test_to_description_hookscript_dash_when_not_configured
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["Hookscript"]
  end

  # ---------------------------
  # to_description() — High Availability section
  # ---------------------------

  def test_to_description_includes_ha
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: base_container_config,
        status: { pid: 54321 },
        snapshots: []
      },
      ha: { managed: 1, group: "ha-group1" }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["High Availability"]
    assert_equal "managed", desc["High Availability"]["State"]
    assert_equal "ha-group1", desc["High Availability"]["Group"]
  end

  def test_to_description_ha_defaults
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["High Availability"]
    assert_equal "-", desc["High Availability"]["State"]
  end

  # ---------------------------
  # to_description() — I/O Statistics section
  # ---------------------------

  def test_to_description_includes_io_statistics
    ct = create_ct_from_data
    desc = @presenter.to_description(ct)

    assert_kind_of Hash, desc["I/O Statistics"]
    assert desc["I/O Statistics"].key?("Network In")
    assert desc["I/O Statistics"].key?("Network Out")
  end

  def test_to_description_io_statistics_dash_when_stopped
    attrs = create_describe_attrs.merge(
      status: "stopped",
      describe_data: {
        config: base_container_config,
        status: {},
        snapshots: []
      }
    )
    ct = Pvectl::Models::Container.new(attrs)
    desc = @presenter.to_description(ct)

    assert_equal "-", desc["I/O Statistics"]
  end

  private

  # Returns base container config hash for describe_data tests.
  def base_container_config
    {
      ostype: "debian", arch: "amd64", unprivileged: 1,
      features: "nesting=1,keyctl=1",
      rootfs: "local-lvm:vm-200-disk-0,size=8G",
      hostname: "web-container.example.com",
      cores: 2, memory: 4096, swap: 512
    }
  end

  # Returns full attribute hash for creating a container with describe_data.
  def create_describe_attrs
    {
      vmid: 200, name: "web-container", node: "pve-node1",
      status: "running", cpu: 0.12, maxcpu: 2,
      mem: 1_073_741_824, maxmem: 4_294_967_296,
      swap: 52_428_800, maxswap: 536_870_912,
      disk: 2_147_483_648, maxdisk: 8_589_934_592,
      uptime: 86400, template: 0, tags: "prod;web",
      pool: nil, netin: 123_456_789, netout: 987_654_321,
      ostype: "debian", arch: "amd64", unprivileged: 1,
      features: "nesting=1,keyctl=1",
      rootfs: "local-lvm:vm-200-disk-0,size=8G",
      network_interfaces: [
        { name: "eth0", bridge: "vmbr0", ip: "192.168.1.50/24", hwaddr: "BC:24:11:AB:CD:EF" }
      ],
      description: "Production web container",
      hostname: "web-container.example.com",
      pid: 54321
    }
  end

  # Creates a Container model with describe_data including config overrides.
  def create_ct_from_data(config_overrides = {})
    config = base_container_config.merge(config_overrides)
    attrs = create_describe_attrs.merge(
      describe_data: {
        config: config,
        status: { pid: 54321 },
        snapshots: []
      }
    )
    Pvectl::Models::Container.new(attrs)
  end

  # Creates container model with describe attributes for testing
  def create_container_with_describe_data(base_container)
    attrs = {
      vmid: base_container.vmid,
      name: base_container.name,
      node: base_container.node,
      status: base_container.status,
      cpu: base_container.cpu,
      maxcpu: base_container.maxcpu,
      mem: base_container.mem,
      maxmem: base_container.maxmem,
      swap: base_container.swap,
      maxswap: base_container.maxswap,
      disk: base_container.disk,
      maxdisk: base_container.maxdisk,
      uptime: base_container.uptime,
      template: base_container.template,
      tags: base_container.tags,
      pool: base_container.pool,
      netin: base_container.netin,
      netout: base_container.netout,
      # Describe-only attributes
      ostype: "debian",
      arch: "amd64",
      unprivileged: 1,
      features: "nesting=1,keyctl=1",
      rootfs: "local-lvm:vm-200-disk-0,size=8G",
      network_interfaces: [
        { name: "eth0", bridge: "vmbr0", ip: "192.168.1.50/24", hwaddr: "BC:24:11:AB:CD:EF" }
      ],
      description: "Production web container",
      hostname: "web-container.example.com",
      pid: 54321
    }

    Pvectl::Models::Container.new(attrs)
  end
end
