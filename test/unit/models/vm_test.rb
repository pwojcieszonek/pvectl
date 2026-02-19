# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::Vm Tests
# =============================================================================

class ModelsVmTest < Minitest::Test
  # Tests for the VM domain model

  def setup
    @running_vm_attrs = {
      vmid: 100,
      name: "web-frontend-1",
      status: "running",
      node: "pve-node1",
      cpu: 0.12,
      maxcpu: 4,
      mem: 2_254_857_830,        # ~2.1 GB
      maxmem: 4_294_967_296,     # 4 GB
      disk: 16_106_127_360,      # ~15 GB
      maxdisk: 53_687_091_200,   # 50 GB
      uptime: 1_314_000,         # ~15 days 3 hours
      template: 0,
      tags: "prod;web",
      hastate: "ignored",
      netin: 123_456_789,
      netout: 987_654_321
    }

    @stopped_vm_attrs = {
      vmid: 200,
      name: "dev-env-alice",
      status: "stopped",
      node: "pve-node3",
      cpu: nil,
      maxcpu: 4,
      mem: nil,
      maxmem: 8_589_934_592,     # 8 GB
      disk: 19_327_352_832,      # ~18 GB
      maxdisk: 53_687_091_200,   # 50 GB
      uptime: nil,
      template: 0,
      tags: "dev;personal",
      hastate: nil,
      netin: nil,
      netout: nil
    }

    @template_attrs = {
      vmid: 9000,
      name: "ubuntu-22-template",
      status: "stopped",
      node: "pve-node1",
      cpu: nil,
      maxcpu: 2,
      mem: nil,
      maxmem: 2_147_483_648,     # 2 GB
      disk: 5_368_709_120,       # 5 GB
      maxdisk: 10_737_418_240,   # 10 GB
      uptime: nil,
      template: 1,
      tags: nil,
      hastate: nil,
      netin: nil,
      netout: nil
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_vm_class_exists
    assert_kind_of Class, Pvectl::Models::Vm
  end

  def test_vm_inherits_from_base
    assert Pvectl::Models::Vm < Pvectl::Models::Base
  end

  # ---------------------------
  # Attribute Readers
  # ---------------------------

  def test_vmid_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 100, vm.vmid
  end

  def test_name_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal "web-frontend-1", vm.name
  end

  def test_status_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal "running", vm.status
  end

  def test_node_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal "pve-node1", vm.node
  end

  def test_cpu_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 0.12, vm.cpu
  end

  def test_maxcpu_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 4, vm.maxcpu
  end

  def test_mem_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 2_254_857_830, vm.mem
  end

  def test_maxmem_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 4_294_967_296, vm.maxmem
  end

  def test_disk_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 16_106_127_360, vm.disk
  end

  def test_maxdisk_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 53_687_091_200, vm.maxdisk
  end

  def test_uptime_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 1_314_000, vm.uptime
  end

  def test_template_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 0, vm.template
  end

  def test_tags_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal "prod;web", vm.tags
  end

  def test_hastate_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal "ignored", vm.hastate
  end

  def test_netin_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 123_456_789, vm.netin
  end

  def test_netout_attribute
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_equal 987_654_321, vm.netout
  end

  # ---------------------------
  # Status Predicate Methods
  # ---------------------------

  def test_running_returns_true_for_running_vm
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert vm.running?
  end

  def test_running_returns_false_for_stopped_vm
    vm = Pvectl::Models::Vm.new(@stopped_vm_attrs)
    refute vm.running?
  end

  def test_stopped_returns_true_for_stopped_vm
    vm = Pvectl::Models::Vm.new(@stopped_vm_attrs)
    assert vm.stopped?
  end

  def test_stopped_returns_false_for_running_vm
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    refute vm.stopped?
  end

  def test_paused_returns_true_for_paused_vm
    attrs = @running_vm_attrs.merge(status: "paused")
    vm = Pvectl::Models::Vm.new(attrs)
    assert vm.paused?
  end

  def test_paused_returns_false_for_running_vm
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    refute vm.paused?
  end

  # ---------------------------
  # Template Predicate Method
  # ---------------------------

  def test_template_returns_true_for_template
    vm = Pvectl::Models::Vm.new(@template_attrs)
    assert vm.template?
  end

  def test_template_returns_false_for_regular_vm
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    refute vm.template?
  end

  # ---------------------------
  # String Keys in Attributes
  # ---------------------------

  def test_accepts_string_keys
    string_attrs = {
      "vmid" => 100,
      "name" => "test",
      "status" => "running",
      "node" => "pve1"
    }
    vm = Pvectl::Models::Vm.new(string_attrs)
    assert_equal 100, vm.vmid
    assert_equal "test", vm.name
  end

  # ---------------------------
  # describe_data Attribute (for describe command)
  # ---------------------------

  def test_describe_data_attribute_defaults_to_nil
    vm = Pvectl::Models::Vm.new(@running_vm_attrs)
    assert_nil vm.describe_data
  end

  def test_describe_data_attribute_when_set
    describe_data = {
      config: { bios: "ovmf", cores: 4 },
      status: { pid: 12345 },
      snapshots: [{ name: "snap1" }],
      agent_ips: [{ name: "eth0" }]
    }
    attrs = @running_vm_attrs.merge(describe_data: describe_data)
    vm = Pvectl::Models::Vm.new(attrs)

    assert_equal describe_data, vm.describe_data
  end

  def test_describe_data_with_empty_hash
    attrs = @running_vm_attrs.merge(describe_data: {})
    vm = Pvectl::Models::Vm.new(attrs)

    assert_equal({}, vm.describe_data)
  end

  def test_describe_data_contains_config_hash
    describe_data = {
      config: {
        bios: "ovmf",
        machine: "q35",
        ostype: "l26",
        sockets: 1,
        cores: 4,
        cpu: "host",
        memory: 8192,
        scsi0: "local-lvm:vm-100-disk-0,size=50G"
      }
    }
    attrs = @running_vm_attrs.merge(describe_data: describe_data)
    vm = Pvectl::Models::Vm.new(attrs)

    assert_equal "ovmf", vm.describe_data[:config][:bios]
    assert_equal 4, vm.describe_data[:config][:cores]
  end

  def test_describe_data_contains_snapshots_array
    describe_data = {
      snapshots: [
        { name: "before-update", snaptime: 1705240365, vmstate: 1 },
        { name: "initial-setup", snaptime: 1704635565, vmstate: 0 }
      ]
    }
    attrs = @running_vm_attrs.merge(describe_data: describe_data)
    vm = Pvectl::Models::Vm.new(attrs)

    assert_equal 2, vm.describe_data[:snapshots].length
    assert_equal "before-update", vm.describe_data[:snapshots][0][:name]
  end

  def test_describe_data_contains_agent_ips_nil_when_agent_unavailable
    describe_data = {
      config: { cores: 4 },
      status: { pid: 123 },
      snapshots: [],
      agent_ips: nil
    }
    attrs = @running_vm_attrs.merge(describe_data: describe_data)
    vm = Pvectl::Models::Vm.new(attrs)

    assert_nil vm.describe_data[:agent_ips]
  end
end
