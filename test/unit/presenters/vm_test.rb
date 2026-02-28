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

  # ---------------------------
  # Header Fields
  # ---------------------------

  def test_to_description_includes_basic_fields
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_equal "web-frontend-1", desc["Name"]
    assert_equal 100, desc["VMID"]
    assert_equal "running", desc["Status"]
    assert_equal "pve-node1", desc["Node"]
    assert_equal "prod, web", desc["Tags"]
    assert_equal "Main production web server", desc["Description"]
  end

  def test_to_description_with_nil_describe_data
    desc = @presenter.to_description(@running_vm)

    # Should handle nil describe_data gracefully
    assert_kind_of Hash, desc
    assert_equal "web-frontend-1", desc["Name"]
  end

  def test_to_description_description_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Description"]
  end

  # ---------------------------
  # Summary Section
  # ---------------------------

  def test_to_description_summary_running_vm
    data = base_describe_data.tap do |d|
      d[:config][:sockets] = 2
      d[:config][:cores] = 4
      d[:status][:pid] = 12345
      d[:status][:"running-qemu"] = "8.1.5"
      d[:status][:"running-machine"] = "pc-i440fx-8.1"
      d[:status][:diskread] = 1_073_741_824
      d[:status][:diskwrite] = 536_870_912
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    summary = desc["Summary"]
    assert_kind_of Hash, summary
    assert_includes summary["CPU Usage"], "of 8 CPU(s)"
    assert_includes summary["Memory Usage"], "GiB"
    refute_nil summary["Uptime"]
    assert_equal "12345", summary["PID"]
    assert_equal "8.1.5", summary["QEMU Version"]
    assert_equal "pc-i440fx-8.1", summary["Machine Type"]
    assert summary.key?("Network In")
    assert summary.key?("Network Out")
    assert summary.key?("Disk Read")
    assert summary.key?("Disk Written")
  end

  def test_to_description_summary_stopped_vm
    data = base_describe_data
    vm = Pvectl::Models::Vm.new(
      @stopped_vm.instance_variable_get(:@attributes).merge(describe_data: data)
    )
    desc = @presenter.to_description(vm)

    summary = desc["Summary"]
    assert_kind_of Hash, summary
    assert_equal "-", summary["HA State"]
    assert_equal "-", summary["CPU Usage"]
    assert_equal "-", summary["Memory Usage"]
    refute summary.key?("Uptime"), "Stopped VM should not have Uptime"
    refute summary.key?("PID"), "Stopped VM should not have PID"
    refute summary.key?("QEMU Version"), "Stopped VM should not have QEMU Version"
  end

  def test_to_description_summary_ha_state
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_equal "ignored", desc["Summary"]["HA State"]
  end

  def test_to_description_summary_bootdisk_from_boot_order
    data = base_describe_data.tap do |d|
      d[:config][:boot] = "order=scsi0;net0"
      d[:config][:scsi0] = "local-lvm:vm-100-disk-0,size=50G,format=raw"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "50G", desc["Summary"]["Bootdisk Size"]
  end

  def test_to_description_summary_bootdisk_fallback_to_maxdisk
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    # Falls back to format_bytes(vm.maxdisk) which is 50.0 GiB
    assert_includes desc["Summary"]["Bootdisk Size"], "GiB"
  end

  def test_to_description_summary_io_statistics_for_running_vm
    data = base_describe_data.tap do |d|
      d[:status][:diskread] = 1_610_612_736
      d[:status][:diskwrite] = 268_435_456
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    summary = desc["Summary"]
    assert_includes summary["Disk Read"], "GiB"
    assert_includes summary["Disk Written"], "MiB"
    assert summary.key?("Network In")
    assert summary.key?("Network Out")
  end

  # ---------------------------
  # Hardware Section
  # ---------------------------

  def test_to_description_hardware_basic
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    hw = desc["Hardware"]
    assert_kind_of Hash, hw
    assert_includes hw["Memory"], "GiB"
    assert_includes hw["Processors"], "sockets"
    assert_includes hw["Processors"], "cores"
    assert_equal "UEFI (OVMF)", hw["BIOS"]
    assert_equal "q35", hw["Machine"]
  end

  def test_to_description_hardware_memory_and_processors
    data = base_describe_data.tap do |d|
      d[:config][:memory] = 8192
      d[:config][:sockets] = 2
      d[:config][:cores] = 4
      d[:config][:cpu] = "host"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    hw = desc["Hardware"]
    assert_equal "8.0 GiB", hw["Memory"]
    assert_equal "8 (2 sockets, 4 cores) [host]", hw["Processors"]
  end

  def test_to_description_hardware_balloon_enabled
    data = base_describe_data.tap { |d| d[:config][:balloon] = 2048 }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_includes desc["Hardware"]["Balloon"], "enabled"
    assert_includes desc["Hardware"]["Balloon"], "2.0 GiB"
  end

  def test_to_description_hardware_balloon_disabled
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "disabled", desc["Hardware"]["Balloon"]
  end

  def test_to_description_hardware_bios_seabios_default
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "SeaBIOS", desc["Hardware"]["BIOS"]
  end

  def test_to_description_hardware_bios_ovmf
    data = base_describe_data.tap { |d| d[:config][:bios] = "ovmf" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "UEFI (OVMF)", desc["Hardware"]["BIOS"]
  end

  def test_to_description_hardware_display_default
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "Default", desc["Hardware"]["Display"]
  end

  def test_to_description_hardware_display_custom
    data = base_describe_data.tap { |d| d[:config][:vga] = "virtio" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "virtio", desc["Hardware"]["Display"]
  end

  def test_to_description_hardware_scsi_controller
    data = base_describe_data.tap { |d| d[:config][:scsihw] = "virtio-scsi-single" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "virtio-scsi-single", desc["Hardware"]["SCSI Controller"]
  end

  def test_to_description_hardware_scsi_controller_default
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "lsi", desc["Hardware"]["SCSI Controller"]
  end

  def test_to_description_hardware_disks
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    disks = desc["Hardware"]["Disks"]
    assert_kind_of Array, disks
    disk = disks.find { |d| d["NAME"] == "scsi0" }
    assert_equal "local-lvm", disk["STORAGE"]
    assert_equal "50G", disk["SIZE"]
    assert_equal "raw", disk["FORMAT"]
  end

  def test_to_description_hardware_disks_ide_format
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

    assert_kind_of Array, desc["Hardware"]["Disks"]
  end

  def test_to_description_hardware_disks_virtio_format
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

    disk = desc["Hardware"]["Disks"].find { |d| d["NAME"] == "virtio0" }
    assert_equal "ceph", disk["STORAGE"]
    assert_equal "100G", disk["SIZE"]
  end

  def test_to_description_hardware_disks_sata_format
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

    disk = desc["Hardware"]["Disks"].find { |d| d["NAME"] == "sata0" }
    assert_equal "local-lvm", disk["STORAGE"]
    assert_equal "250G", disk["SIZE"]
  end

  def test_to_description_hardware_disks_dash_when_none
    describe_data = { config: { cores: 4 } }
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "test", status: "running", node: "pve1",
      describe_data: describe_data
    )
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["Disks"]
  end

  def test_to_description_hardware_network
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    network = desc["Hardware"]["Network"]
    assert_kind_of Array, network
    net = network.find { |n| n["NAME"] == "net0" }
    assert_equal "virtio", net["MODEL"]
    assert_equal "vmbr0", net["BRIDGE"]
    assert_equal "BC:24:11:AA:BB:CC", net["MAC"]
    assert_equal "192.168.1.100", net["IP"]
  end

  def test_to_description_hardware_network_no_agent_ip
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

    net = desc["Hardware"]["Network"].find { |n| n["NAME"] == "net0" }
    assert_equal "-", net["IP"]
  end

  def test_to_description_hardware_network_firewall
    data = base_describe_data.tap do |d|
      d[:config][:net0] = "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0,firewall=1"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    network = desc["Hardware"]["Network"]
    assert_kind_of Array, network
    assert_equal "yes", network.first["FIREWALL"]
  end

  def test_to_description_hardware_network_firewall_no_by_default
    data = base_describe_data.tap do |d|
      d[:config][:net0] = "virtio=BC:24:11:AA:BB:CC,bridge=vmbr0"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    network = desc["Hardware"]["Network"]
    assert_kind_of Array, network
    assert_equal "no", network.first["FIREWALL"]
  end

  def test_to_description_hardware_efi_disk
    data = base_describe_data.tap { |d| d[:config][:efidisk0] = "local-lvm:vm-100-disk-1,efitype=4m,pre-enrolled-keys=1,size=4M" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_includes desc["Hardware"]["EFI Disk"], "local-lvm"
  end

  def test_to_description_hardware_efi_disk_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["EFI Disk"]
  end

  def test_to_description_hardware_tpm
    data = base_describe_data.tap { |d| d[:config][:tpmstate0] = "local-lvm:vm-100-disk-2,size=4M,version=v2.0" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_includes desc["Hardware"]["TPM"], "local-lvm"
  end

  def test_to_description_hardware_tpm_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["TPM"]
  end

  def test_to_description_hardware_usb_devices
    data = base_describe_data.tap do |d|
      d[:config][:usb0] = "host=1234:5678"
      d[:config][:usb1] = "spice"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    usb = desc["Hardware"]["USB Devices"]
    assert_kind_of Array, usb
    assert_equal 2, usb.length
    assert_equal "usb0", usb.first["NAME"]
    assert_equal "host=1234:5678", usb.first["CONFIG"]
  end

  def test_to_description_hardware_usb_dash_when_none
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["USB Devices"]
  end

  def test_to_description_hardware_pci_passthrough
    data = base_describe_data.tap do |d|
      d[:config][:hostpci0] = "0000:01:00.0,pcie=1,x-vga=1"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    pci = desc["Hardware"]["PCI Passthrough"]
    assert_kind_of Array, pci
    assert_equal 1, pci.length
    assert_equal "hostpci0", pci.first["NAME"]
    assert_equal "0000:01:00.0,pcie=1,x-vga=1", pci.first["CONFIG"]
  end

  def test_to_description_hardware_pci_dash_when_none
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["PCI Passthrough"]
  end

  def test_to_description_hardware_serial_ports
    data = base_describe_data.tap do |d|
      d[:config][:serial0] = "socket"
      d[:config][:serial1] = "/dev/ttyS0"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    serial = desc["Hardware"]["Serial Ports"]
    assert_kind_of Array, serial
    assert_equal 2, serial.length
    assert_equal "serial0", serial.first["NAME"]
    assert_equal "socket", serial.first["TYPE"]
  end

  def test_to_description_hardware_serial_dash_when_none
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["Serial Ports"]
  end

  def test_to_description_hardware_audio
    data = base_describe_data.tap { |d| d[:config][:audio0] = "device=ich9-intel-hda,driver=spice" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "device=ich9-intel-hda,driver=spice", desc["Hardware"]["Audio"]
  end

  def test_to_description_hardware_audio_dash_when_none
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Hardware"]["Audio"]
  end

  # ---------------------------
  # Cloud-Init Section
  # ---------------------------

  def test_to_description_includes_cloud_init_section
    data = base_describe_data.tap do |d|
      d[:config].merge!(
        citype: "nocloud",
        ciuser: "admin",
        ipconfig0: "ip=192.168.1.100/24,gw=192.168.1.1",
        ipconfig1: "ip=10.0.0.5/24",
        nameserver: "8.8.8.8",
        searchdomain: "example.com",
        sshkeys: "ssh-rsa%20AAAA...%20user%40host"
      )
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_kind_of Hash, desc["Cloud-Init"]
    assert_equal "nocloud", desc["Cloud-Init"]["Type"]
    assert_equal "admin", desc["Cloud-Init"]["User"]
    assert_equal "8.8.8.8", desc["Cloud-Init"]["DNS Server"]
    assert_equal "example.com", desc["Cloud-Init"]["Search Domain"]
    assert_equal "configured", desc["Cloud-Init"]["SSH Keys"]
    assert_kind_of Array, desc["Cloud-Init"]["IP Config"]
    assert_equal 2, desc["Cloud-Init"]["IP Config"].length
    assert_equal "net0", desc["Cloud-Init"]["IP Config"].first["INTERFACE"]
  end

  def test_to_description_cloud_init_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Cloud-Init"]
  end

  # ---------------------------
  # Options Section
  # ---------------------------

  def test_to_description_options_defaults
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    options = desc["Options"]
    assert_kind_of Hash, options
    assert_equal "No", options["Start at Boot"]
    assert_equal "Yes", options["ACPI Support"]
    assert_equal "Yes", options["KVM Hardware Virtualization"]
    assert_equal "Yes", options["Use Tablet for Pointer"]
    assert_equal "No", options["Freeze CPU at Startup"]
    assert_equal "Default", options["Use Local Time for RTC"]
    assert_equal "No", options["NUMA"]
    assert_equal "No", options["Protection"]
    assert_equal "No", options["Firewall"]
  end

  def test_to_description_options_boot_order
    data = base_describe_data.tap { |d| d[:config][:boot] = "order=scsi0;ide2;net0" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "scsi0, ide2, net0", desc["Options"]["Boot Order"]
  end

  def test_to_description_options_boot_order_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Options"]["Boot Order"]
  end

  def test_to_description_options_agent_inline
    data = base_describe_data.tap { |d| d[:config][:agent] = "1,type=virtio" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "Enabled, Type: virtio", desc["Options"]["QEMU Guest Agent"]
  end

  def test_to_description_options_agent_with_fstrim
    data = base_describe_data.tap do |d|
      d[:config][:agent] = "1,fstrim_cloned_disks=1,freeze-fs-on-backup=1,type=virtio"
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    agent = desc["Options"]["QEMU Guest Agent"]
    assert_includes agent, "Enabled"
    assert_includes agent, "Type: virtio"
    assert_includes agent, "Trim Cloned Disks: yes"
    assert_includes agent, "Freeze FS on Backup: yes"
  end

  def test_to_description_options_agent_disabled
    data = base_describe_data.tap { |d| d[:config][:agent] = "0" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "Disabled", desc["Options"]["QEMU Guest Agent"]
  end

  def test_to_description_options_agent_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "Disabled", desc["Options"]["QEMU Guest Agent"]
  end

  def test_to_description_options_startup_order
    data = base_describe_data.tap do |d|
      d[:config][:startup] = "order=1,up=30,down=60"
      d[:config][:onboot] = 1
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "order=1,up=30,down=60", desc["Options"]["Start/Shutdown Order"]
    assert_equal "Yes", desc["Options"]["Start at Boot"]
  end

  def test_to_description_options_startup_defaults
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Options"]["Start/Shutdown Order"]
    assert_equal "No", desc["Options"]["Start at Boot"]
  end

  def test_to_description_options_hotplug
    data = base_describe_data.tap { |d| d[:config][:hotplug] = "disk,network,usb" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "disk, network, usb", desc["Options"]["Hotplug"]
  end

  def test_to_description_options_hotplug_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Options"]["Hotplug"]
  end

  def test_to_description_options_hookscript
    data = base_describe_data.tap { |d| d[:config][:hookscript] = "local:snippets/hook.pl" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "local:snippets/hook.pl", desc["Options"]["Hookscript"]
  end

  def test_to_description_options_hookscript_dash_when_absent
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "-", desc["Options"]["Hookscript"]
  end

  def test_to_description_options_ostype
    data = base_describe_data.tap { |d| d[:config][:ostype] = "l26" }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "l26 (Linux 2.6+)", desc["Options"]["OS Type"]
  end

  def test_to_description_options_security
    data = base_describe_data.tap do |d|
      d[:config].merge!(protection: 1, firewall: 1)
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "Yes", desc["Options"]["Protection"]
    assert_equal "Yes", desc["Options"]["Firewall"]
  end

  # ---------------------------
  # Task History Section
  # ---------------------------

  def test_to_description_task_history_present
    task = Pvectl::Models::TaskEntry.new(
      type: "qmstart", status: "stopped", exitstatus: "OK",
      starttime: 1_700_000_000, endtime: 1_700_000_005, user: "root@pam", node: "pve1"
    )
    data = base_describe_data.tap { |d| d[:tasks] = [task] }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_kind_of Array, desc["Task History"]
    assert_equal "qmstart", desc["Task History"].first["TYPE"]
    assert_equal "OK", desc["Task History"].first["STATUS"]
    assert_equal "5s", desc["Task History"].first["DURATION"]
    assert_equal "root@pam", desc["Task History"].first["USER"]
  end

  def test_to_description_task_history_empty
    data = base_describe_data.tap { |d| d[:tasks] = [] }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "No task history", desc["Task History"]
  end

  def test_to_description_task_history_nil
    data = base_describe_data
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "No task history", desc["Task History"]
  end

  # ---------------------------
  # Snapshots Section
  # ---------------------------

  def test_to_description_snapshots_present
    vm_with_describe_data = create_vm_with_describe_data(@running_vm)
    desc = @presenter.to_description(vm_with_describe_data)

    assert_kind_of Array, desc["Snapshots"]
    snap = desc["Snapshots"].find { |s| s["NAME"] == "before-update" }
    assert_equal "yes", snap["VMSTATE"]
    assert_equal "Before system update", snap["DESCRIPTION"]
    assert_match(/\d{4}-\d{2}-\d{2}/, snap["DATE"])
  end

  def test_to_description_snapshots_empty
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

  # ---------------------------
  # Pending Changes Section
  # ---------------------------

  def test_to_description_includes_pending_changes
    data = base_describe_data.tap do |d|
      d[:pending] = [
        { key: "memory", value: 4096, pending: 8192 },
        { key: "cores", value: 2, pending: 4 }
      ]
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_kind_of Array, desc["Pending Changes"]
    assert_equal 2, desc["Pending Changes"].length
    assert_equal "memory", desc["Pending Changes"].first["KEY"]
    assert_equal "4096", desc["Pending Changes"].first["CURRENT"]
    assert_equal "8192", desc["Pending Changes"].first["PENDING"]
  end

  def test_to_description_pending_filters_unchanged_entries
    data = base_describe_data.tap do |d|
      d[:pending] = [
        { key: "memory", value: 4096, pending: 8192 },
        { key: "cores", value: 2 },
        { key: "sockets", value: 1 }
      ]
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_kind_of Array, desc["Pending Changes"]
    assert_equal 1, desc["Pending Changes"].length
    assert_equal "memory", desc["Pending Changes"].first["KEY"]
  end

  def test_to_description_pending_no_changes_when_empty
    data = base_describe_data.tap { |d| d[:pending] = [] }
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "No pending changes", desc["Pending Changes"]
  end

  def test_to_description_pending_no_changes_when_all_current
    data = base_describe_data.tap do |d|
      d[:pending] = [
        { key: "memory", value: 4096 },
        { key: "cores", value: 2 }
      ]
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    assert_equal "No pending changes", desc["Pending Changes"]
  end

  # ---------------------------
  # Catch-All / Additional Configuration
  # ---------------------------

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

  # ---------------------------
  # Misc Keys Consumed via Options
  # ---------------------------

  def test_to_description_misc_keys_consumed
    data = base_describe_data.tap do |d|
      d[:config].merge!(acpi: 1, tablet: 1, kvm: 1, numa0: "cpus=0-3,memory=4096")
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    additional = desc["Additional Configuration"]
    if additional.is_a?(Array)
      keys = additional.map { |row| row["KEY"] }
      refute_includes keys, "acpi"
      refute_includes keys, "tablet"
      refute_includes keys, "kvm"
      refute_includes keys, "numa0"
    end
  end

  def test_to_description_hardware_keys_consumed
    data = base_describe_data.tap do |d|
      d[:config].merge!(vga: "virtio", shares: 1000, vcpus: 4, cpulimit: 2, cpuunits: 2048)
    end
    vm = create_vm_from_data(data)
    desc = @presenter.to_description(vm)

    additional = desc["Additional Configuration"]
    if additional.is_a?(Array)
      keys = additional.map { |row| row["KEY"] }
      refute_includes keys, "vga"
      refute_includes keys, "shares"
      refute_includes keys, "vcpus"
      refute_includes keys, "cpulimit"
      refute_includes keys, "cpuunits"
    end
  end

  def test_to_description_bootdisk_size_fallback_for_cdrom
    data = base_describe_data.tap do |d|
      d[:config][:boot] = "order=ide2"
      d[:config][:ide2] = "local:iso/ubuntu.iso,media=cdrom"
    end
    vm = Pvectl::Models::Vm.new(
      @running_vm.instance_variable_get(:@attributes).merge(
        maxdisk: 53_687_091_200,
        describe_data: data
      )
    )
    desc = @presenter.to_description(vm)

    # Boot device is CD-ROM without size= — should fallback to maxdisk
    assert_includes desc["Summary"]["Bootdisk Size"], "GiB"
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
