# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Vm Tests
# =============================================================================

class PresentersVmTest < Minitest::Test
  # Tests for the VM presenter

  def setup
    @running_vm = Pvectl::Models::Vm.new(
      vmid: 100,
      name: "web-frontend-1",
      status: "running",
      node: "pve-node1",
      cpu: 0.12,
      maxcpu: 4,
      mem: 2_254_857_830,
      maxmem: 4_294_967_296,
      disk: 16_106_127_360,
      maxdisk: 53_687_091_200,
      uptime: 1_314_000,
      template: 0,
      tags: "prod;web",
      hastate: "ignored",
      netin: 123_456_789,
      netout: 987_654_321
    )

    @stopped_vm = Pvectl::Models::Vm.new(
      vmid: 200,
      name: "dev-env-alice",
      status: "stopped",
      node: "pve-node3",
      cpu: nil,
      maxcpu: 4,
      mem: nil,
      maxmem: 8_589_934_592,
      disk: 19_327_352_832,
      maxdisk: 53_687_091_200,
      uptime: nil,
      template: 0,
      tags: "dev;personal",
      hastate: nil,
      netin: nil,
      netout: nil
    )

    @template_vm = Pvectl::Models::Vm.new(
      vmid: 9000,
      name: "ubuntu-template",
      status: "stopped",
      node: "pve-node1",
      cpu: nil,
      maxcpu: 2,
      mem: nil,
      maxmem: 2_147_483_648,
      disk: 5_368_709_120,
      maxdisk: 10_737_418_240,
      uptime: nil,
      template: 1,
      tags: nil,
      hastate: nil,
      netin: nil,
      netout: nil
    )

    @presenter = Pvectl::Presenters::Vm.new
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_vm_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::Vm
  end

  def test_vm_presenter_inherits_from_base
    assert Pvectl::Presenters::Vm < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns() Method
  # ---------------------------

  def test_columns_returns_expected_headers
    expected = %w[NAME VMID STATUS NODE CPU MEMORY]
    assert_equal expected, @presenter.columns
  end

  # ---------------------------
  # extra_columns() Method
  # ---------------------------

  def test_extra_columns_returns_wide_headers
    expected = %w[UPTIME TEMPLATE TAGS DISK IP AGENT HA BACKUP]
    assert_equal expected, @presenter.extra_columns
  end

  # ---------------------------
  # wide_columns() Method
  # ---------------------------

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[NAME VMID STATUS NODE CPU MEMORY UPTIME TEMPLATE TAGS DISK IP AGENT HA BACKUP]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row() Method - Running VM
  # ---------------------------

  def test_to_row_for_running_vm
    row = @presenter.to_row(@running_vm)

    assert_equal 6, row.length
    assert_equal "web-frontend-1", row[0] # NAME
    assert_equal "100", row[1]            # VMID
    assert_equal "running", row[2]        # STATUS
    assert_equal "pve-node1", row[3]      # NODE
    assert_equal "12%/4", row[4]          # CPU
    assert_equal "2.1/4.0 GB", row[5]     # MEMORY
  end

  # ---------------------------
  # to_row() Method - Stopped VM
  # ---------------------------

  def test_to_row_for_stopped_vm
    row = @presenter.to_row(@stopped_vm)

    assert_equal 6, row.length
    assert_equal "dev-env-alice", row[0]  # NAME
    assert_equal "200", row[1]            # VMID
    assert_equal "stopped", row[2]        # STATUS
    assert_equal "pve-node3", row[3]      # NODE
    assert_equal "-/4", row[4]            # CPU
    assert_equal "-/8.0 GB", row[5]       # MEMORY
  end

  # ---------------------------
  # to_row() Method - Template
  # ---------------------------

  def test_to_row_for_template
    row = @presenter.to_row(@template_vm)

    assert_equal 6, row.length
    assert_equal "ubuntu-template", row[0] # NAME
    assert_equal "9000", row[1]            # VMID
    assert_equal "stopped", row[2]         # STATUS
    assert_equal "pve-node1", row[3]       # NODE
    assert_equal "-/2", row[4]             # CPU
    assert_equal "-/2.0 GB", row[5]        # MEMORY
  end

  # ---------------------------
  # extra_values() Method
  # ---------------------------

  def test_extra_values_for_running_vm
    extra = @presenter.extra_values(@running_vm)

    assert_equal 8, extra.length
    assert_equal "15d 5h", extra[0]    # UPTIME
    assert_equal "-", extra[1]          # TEMPLATE
    assert_equal "prod, web", extra[2]  # TAGS
    assert_equal "15/50 GB", extra[3]   # DISK
    assert_equal "-", extra[4]          # IP
    assert_equal "-", extra[5]          # AGENT
    assert_equal "ignored", extra[6]    # HA
    assert_equal "-", extra[7]          # BACKUP
  end

  def test_extra_values_for_vm_without_hastate
    extra = @presenter.extra_values(@stopped_vm)

    assert_equal 8, extra.length
    assert_equal "-", extra[0]             # UPTIME
    assert_equal "-", extra[1]             # TEMPLATE
    assert_equal "dev, personal", extra[2] # TAGS
    assert_equal "18/50 GB", extra[3]      # DISK
    assert_equal "-", extra[4]             # IP
    assert_equal "-", extra[5]             # AGENT
    assert_equal "-", extra[6]             # HA
    assert_equal "-", extra[7]             # BACKUP
  end

  # ---------------------------
  # to_wide_row() Method
  # ---------------------------

  def test_to_wide_row_combines_row_and_extra_values
    wide_row = @presenter.to_wide_row(@running_vm)

    assert_equal 14, wide_row.length
    assert_equal "web-frontend-1", wide_row[0]  # NAME
    assert_equal "100", wide_row[1]              # VMID
    assert_equal "15d 5h", wide_row[6]           # UPTIME (first extra)
    assert_equal "ignored", wide_row[12]         # HA
  end

  # ---------------------------
  # to_hash() Method
  # ---------------------------

  def test_to_hash_returns_complete_vm_data
    hash = @presenter.to_hash(@running_vm)

    assert_equal 100, hash["vmid"]
    assert_equal "web-frontend-1", hash["name"]
    assert_equal "running", hash["status"]
    assert_equal "pve-node1", hash["node"]
    refute hash["template"]
  end

  def test_to_hash_includes_cpu_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["cpu"]
    assert_equal 12, hash["cpu"]["usage_percent"]
    assert_equal 4, hash["cpu"]["cores"]
  end

  def test_to_hash_includes_memory_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["memory"]
    assert_equal 2.1, hash["memory"]["used_gb"]
    assert_equal 4.0, hash["memory"]["total_gb"]
    assert_equal 2_254_857_830, hash["memory"]["used_bytes"]
    assert_equal 4_294_967_296, hash["memory"]["total_bytes"]
  end

  def test_to_hash_includes_disk_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["disk"]
    assert_equal 15, hash["disk"]["used_gb"]
    assert_equal 50, hash["disk"]["total_gb"]
    assert_equal 16_106_127_360, hash["disk"]["used_bytes"]
    assert_equal 53_687_091_200, hash["disk"]["total_bytes"]
  end

  def test_to_hash_includes_uptime_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["uptime"]
    assert_equal 1_314_000, hash["uptime"]["seconds"]
    assert_equal "15d 5h", hash["uptime"]["human"]
  end

  def test_to_hash_includes_network_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["network"]
    assert_equal 123_456_789, hash["network"]["in_bytes"]
    assert_equal 987_654_321, hash["network"]["out_bytes"]
  end

  def test_to_hash_includes_ha_nested_structure
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Hash, hash["ha"]
    assert_equal "ignored", hash["ha"]["state"]
  end

  def test_to_hash_includes_tags_as_array
    hash = @presenter.to_hash(@running_vm)

    assert_kind_of Array, hash["tags"]
    assert_equal ["prod", "web"], hash["tags"]
  end

  def test_to_hash_template_flag_is_boolean
    hash = @presenter.to_hash(@template_vm)
    assert_equal true, hash["template"]

    hash = @presenter.to_hash(@running_vm)
    assert_equal false, hash["template"]
  end

  def test_to_hash_for_stopped_vm_has_nil_cpu_percent
    hash = @presenter.to_hash(@stopped_vm)

    assert_nil hash["cpu"]["usage_percent"]
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_to_row_accepts_context_kwargs
    row = @presenter.to_row(@running_vm, current_context: "prod")
    assert_kind_of Array, row
  end

  def test_extra_values_accepts_context_kwargs
    extra = @presenter.extra_values(@running_vm, highlight: true)
    assert_kind_of Array, extra
  end

  # ---------------------------
  # Display Methods (moved from Model)
  # ---------------------------

  def test_display_name_returns_name_when_present
    @presenter.to_row(@running_vm)
    assert_equal "web-frontend-1", @presenter.display_name
  end

  def test_display_name_returns_fallback_when_name_nil
    vm = Pvectl::Models::Vm.new(vmid: 100, name: nil, status: "running", node: "pve1")
    @presenter.to_row(vm)
    assert_equal "VM-100", @presenter.display_name
  end

  def test_cpu_percent_for_running_vm
    @presenter.to_row(@running_vm)
    assert_equal "12%/4", @presenter.cpu_percent
  end

  def test_cpu_percent_for_stopped_vm
    @presenter.to_row(@stopped_vm)
    assert_equal "-/4", @presenter.cpu_percent
  end

  def test_cpu_percent_with_nil_cpu
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: nil, maxcpu: 4
    )
    @presenter.to_row(vm)
    assert_equal "-/4", @presenter.cpu_percent
  end

  def test_cpu_percent_rounds_value
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: 0.456, maxcpu: 4
    )
    @presenter.to_row(vm)
    assert_equal "46%/4", @presenter.cpu_percent
  end

  def test_cpu_percent_with_nil_maxcpu
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      cpu: 0.12, maxcpu: nil
    )
    @presenter.to_row(vm)
    assert_equal "-", @presenter.cpu_percent
  end

  def test_memory_used_gb_for_running_vm
    @presenter.to_row(@running_vm)
    assert_equal 2.1, @presenter.memory_used_gb
  end

  def test_memory_used_gb_returns_nil_when_mem_nil
    @presenter.to_row(@stopped_vm)
    assert_nil @presenter.memory_used_gb
  end

  def test_memory_total_gb
    @presenter.to_row(@running_vm)
    assert_equal 4.0, @presenter.memory_total_gb
  end

  def test_memory_total_gb_returns_nil_when_maxmem_nil
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      mem: 2_254_857_830, maxmem: nil
    )
    @presenter.to_row(vm)
    assert_nil @presenter.memory_total_gb
  end

  def test_memory_display_for_running_vm
    @presenter.to_row(@running_vm)
    assert_equal "2.1/4.0 GB", @presenter.memory_display
  end

  def test_memory_display_for_stopped_vm
    @presenter.to_row(@stopped_vm)
    assert_equal "-/8.0 GB", @presenter.memory_display
  end

  def test_memory_display_with_nil_maxmem
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      mem: 2_254_857_830, maxmem: nil
    )
    @presenter.to_row(vm)
    assert_equal "-", @presenter.memory_display
  end

  def test_disk_used_gb
    @presenter.to_row(@running_vm)
    assert_equal 15, @presenter.disk_used_gb
  end

  def test_disk_used_gb_returns_nil_when_disk_nil
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: nil, maxdisk: 53_687_091_200
    )
    @presenter.to_row(vm)
    assert_nil @presenter.disk_used_gb
  end

  def test_disk_total_gb
    @presenter.to_row(@running_vm)
    assert_equal 50, @presenter.disk_total_gb
  end

  def test_disk_total_gb_returns_nil_when_maxdisk_nil
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: 16_106_127_360, maxdisk: nil
    )
    @presenter.to_row(vm)
    assert_nil @presenter.disk_total_gb
  end

  def test_disk_display
    @presenter.to_row(@running_vm)
    assert_equal "15/50 GB", @presenter.disk_display
  end

  def test_disk_display_returns_dash_when_disk_nil
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      disk: nil, maxdisk: 53_687_091_200
    )
    @presenter.to_row(vm)
    assert_equal "-", @presenter.disk_display
  end

  # ---------------------------
  # to_description() Method
  # ---------------------------

  def test_to_description_returns_hash
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc
  end

  def test_to_description_includes_basic_fields
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_equal "web-frontend-1", desc["Name"]
    assert_equal 100, desc["VMID"]
    assert_equal "running", desc["Status"]
    assert_equal "pve-node1", desc["Node"]
    assert_equal "no", desc["Template"]
  end

  def test_to_description_includes_system_section
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["System"]
    assert_equal "UEFI (OVMF)", desc["System"]["BIOS"]
    assert_equal "q35", desc["System"]["Machine"]
    assert_equal "l26 (Linux 2.6+)", desc["System"]["OS Type"]
  end

  def test_to_description_includes_cpu_section
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["CPU"]
    assert_equal 1, desc["CPU"]["Sockets"]
    assert_equal 4, desc["CPU"]["Cores"]
    assert_equal "host", desc["CPU"]["Type"]
    assert_equal "12%", desc["CPU"]["Usage"]
  end

  def test_to_description_includes_memory_section
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["Memory"]
    assert_includes desc["Memory"]["Total"], "GiB"
    assert_includes desc["Memory"]["Balloon"], "enabled"
  end

  def test_to_description_parses_disks_scsi_format
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Array, desc["Disks"]
    assert desc["Disks"].any? { |d| d["NAME"] == "scsi0" }

    disk = desc["Disks"].find { |d| d["NAME"] == "scsi0" }
    assert_equal "local-lvm", disk["STORAGE"]
    assert_equal "50G", disk["SIZE"]
    assert_equal "raw", disk["FORMAT"]
  end

  def test_to_description_parses_disks_ide_format
    describe_data = {
      config: {
        ide0: "local:iso/ubuntu.iso,media=cdrom",
        ide2: "local-lvm:vm-100-disk-1,size=20G,format=qcow2"
      }
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    assert_kind_of Array, desc["Disks"]
  end

  def test_to_description_parses_disks_virtio_format
    describe_data = {
      config: {
        virtio0: "ceph:vm-100-disk-0,size=100G"
      }
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    disk = desc["Disks"].find { |d| d["NAME"] == "virtio0" }
    assert_equal "ceph", disk["STORAGE"]
    assert_equal "100G", disk["SIZE"]
  end

  def test_to_description_parses_disks_sata_format
    describe_data = {
      config: {
        sata0: "local-lvm:vm-100-disk-0,size=250G,format=raw"
      }
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    disk = desc["Disks"].find { |d| d["NAME"] == "sata0" }
    assert_equal "local-lvm", disk["STORAGE"]
    assert_equal "250G", disk["SIZE"]
  end

  def test_to_description_returns_dash_when_no_disks
    describe_data = { config: { cores: 4 } }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Disks"]
  end

  def test_to_description_parses_network_virtio_with_mac_and_bridge
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Array, desc["Network"]
    net = desc["Network"].find { |n| n["NAME"] == "net0" }
    assert_equal "virtio", net["MODEL"]
    assert_equal "vmbr0", net["BRIDGE"]
    assert_equal "BC:24:11:AA:BB:CC", net["MAC"]
    assert_equal "192.168.1.100", net["IP"]
  end

  def test_to_description_network_shows_dash_when_no_agent_ip
    describe_data = {
      config: {
        net0: "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0"
      },
      agent_ips: nil
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    net = desc["Network"].find { |n| n["NAME"] == "net0" }
    assert_equal "-", net["IP"]
  end

  def test_to_description_formats_snapshots
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Array, desc["Snapshots"]
    snap = desc["Snapshots"].find { |s| s["NAME"] == "before-update" }
    assert_equal "yes", snap["VMSTATE"]
    assert_equal "Before system update", snap["DESCRIPTION"]
    assert_match(/\d{4}-\d{2}-\d{2}/, snap["DATE"])
  end

  def test_to_description_returns_no_snapshots_message_when_empty
    describe_data = {
      config: { cores: 4 },
      snapshots: []
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    assert_equal "No snapshots", desc["Snapshots"]
  end

  def test_to_description_stopped_vm_runtime_shows_dash
    describe_data = {
      config: { cores: 4 },
      status: { status: "stopped" }
    }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "stopped", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Runtime"]
  end

  def test_to_description_running_vm_includes_runtime_section
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["Runtime"]
    assert_equal "15d 5h", desc["Runtime"]["Uptime"]
    assert_equal 12345, desc["Runtime"]["PID"]
    assert_equal "8.1.5", desc["Runtime"]["QEMU Version"]
    assert_equal "pc-q35-8.1", desc["Runtime"]["Machine Type"]
  end

  def test_to_description_includes_network_io_for_running_vm
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["Network I/O"]
    assert_includes desc["Network I/O"]["Received"], "MiB"
    assert_includes desc["Network I/O"]["Transmitted"], "MiB"
  end

  def test_to_description_stopped_vm_network_io_shows_dash
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "stopped", node: "pve1",
      describe_data: { config: {} }
    )
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Network I/O"]
  end

  def test_to_description_includes_ha_section
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Hash, desc["High Availability"]
    assert_equal "ignored", desc["High Availability"]["State"]
  end

  def test_to_description_includes_tags
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_equal "prod, web", desc["Tags"]
  end

  def test_to_description_includes_description
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_equal "Main production web server", desc["Description"]
  end

  def test_to_description_with_nil_describe_data
    desc = @presenter.to_description(@running_vm)

    # Should handle nil describe_data gracefully
    assert_kind_of Hash, desc
    assert_equal "web-frontend-1", desc["Name"]
  end

  def test_to_description_includes_pool
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert desc.key?("Pool")
  end

  def test_to_description_catch_all_shows_unknown_keys
    data = base_describe_data.tap do |d|
      d[:config][:some_future_key] = "future_value"
      d[:config][:another_unknown] = "42"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert desc.key?("Additional Configuration"), "Should have Additional Configuration section"
    additional = desc["Additional Configuration"]
    assert_kind_of Array, additional
    keys = additional.map { |row| row["KEY"] }
    assert_includes keys, "some_future_key"
    assert_includes keys, "another_unknown"
  end

  def test_to_description_catch_all_excludes_digest
    data = base_describe_data.tap { |d| d[:config][:digest] = "abc123def456" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    additional = desc["Additional Configuration"]
    if additional.is_a?(Array)
      keys = additional.map { |row| row["KEY"] }
      refute_includes keys, "digest"
    end
  end

  def test_to_description_catch_all_dash_when_all_consumed
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Additional Configuration"]
  end

  def test_to_description_includes_additional_configuration_key
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert desc.key?("Additional Configuration")
  end

  private

  def base_describe_data
    {
      config: {
        bios: "seabios", machine: "i440fx", ostype: "l26",
        sockets: 1, cores: 1, cpu: "kvm64", memory: 2048
      },
      status: { status: "running", pid: 12345 },
      snapshots: [],
      agent_ips: nil
    }
  end

  def create_vm_from_data(data)
    Pvectl::Models::Vm.new(
      @running_vm.instance_variable_get(:@attributes).merge(describe_data: data)
    )
  end

  # Creates VM model with describe_data for testing
  def create_vm_with_describe_data(base_vm)
    describe_data = {
      config: {
        bios: "ovmf",
        machine: "q35",
        ostype: "l26",
        sockets: 1,
        cores: 4,
        cpu: "host",
        memory: 8192,
        balloon: 2048,
        scsi0: "local-lvm:vm-100-disk-0,size=50G,format=raw",
        net0: "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0,firewall=1",
        description: "Main production web server",
        ha: "ha-group-1"
      },
      status: {
        status: "running",
        pid: 12345,
        "running-qemu": "8.1.5",
        "running-machine": "pc-q35-8.1"
      },
      snapshots: [
        { name: "before-update", snaptime: 1705240365, vmstate: 1, description: "Before system update" },
        { name: "initial-setup", snaptime: 1704635565, vmstate: 0, description: "Initial configuration" }
      ],
      agent_ips: [
        { name: "lo", "hardware-address": "00:00:00:00:00:00", "ip-addresses": [{ "ip-address": "127.0.0.1", "ip-address-type": "ipv4" }] },
        { name: "eth0", "hardware-address": "bc:24:11:aa:bb:cc", "ip-addresses": [{ "ip-address": "192.168.1.100", "ip-address-type": "ipv4" }] }
      ]
    }

    Pvectl::Models::Vm.new(
      base_vm.instance_variable_get(:@attributes).merge(describe_data: describe_data)
    )
  end
end
