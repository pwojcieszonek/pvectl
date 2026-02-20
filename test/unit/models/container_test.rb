# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::Container Tests
# =============================================================================

class ModelsContainerTest < Minitest::Test
  # Tests for the Container (LXC) domain model

  def setup
    @running_container_attrs = {
      vmid: 100,
      name: "web-frontend",
      node: "pve-node1",
      status: "running",
      cpu: 0.05,
      maxcpu: 2,
      mem: 536_870_912,              # 512 MB
      maxmem: 1_073_741_824,         # 1 GB
      swap: 0,
      maxswap: 536_870_912,          # 512 MB
      disk: 2_147_483_648,           # 2 GB
      maxdisk: 8_589_934_592,        # 8 GB
      uptime: 864_000,               # 10 days
      template: 0,
      tags: "prod;web",
      pool: "production",
      lock: nil,
      netin: 123_456_789,
      netout: 987_654_321
    }

    @stopped_container_attrs = {
      vmid: 200,
      name: "dev-container",
      node: "pve-node2",
      status: "stopped",
      cpu: nil,
      maxcpu: 1,
      mem: nil,
      maxmem: 536_870_912,           # 512 MB
      swap: nil,
      maxswap: 268_435_456,          # 256 MB
      disk: 1_073_741_824,           # 1 GB
      maxdisk: 4_294_967_296,        # 4 GB
      uptime: nil,
      template: 0,
      tags: "dev",
      pool: nil,
      lock: nil,
      netin: nil,
      netout: nil
    }

    @template_attrs = {
      vmid: 9000,
      name: "debian-12-template",
      node: "pve-node1",
      status: "stopped",
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
      lock: nil,
      netin: nil,
      netout: nil
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_container_class_exists
    assert_kind_of Class, Pvectl::Models::Container
  end

  def test_container_inherits_from_base
    assert Pvectl::Models::Container < Pvectl::Models::Base
  end

  # ---------------------------
  # Identifier Attributes
  # ---------------------------

  def test_vmid_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 100, container.vmid
  end

  def test_name_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal "web-frontend", container.name
  end

  def test_node_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal "pve-node1", container.node
  end

  def test_status_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal "running", container.status
  end

  # ---------------------------
  # Resource Attributes
  # ---------------------------

  def test_cpu_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 0.05, container.cpu
  end

  def test_maxcpu_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 2, container.maxcpu
  end

  def test_mem_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 536_870_912, container.mem
  end

  def test_maxmem_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 1_073_741_824, container.maxmem
  end

  def test_swap_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 0, container.swap
  end

  def test_maxswap_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 536_870_912, container.maxswap
  end

  def test_disk_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 2_147_483_648, container.disk
  end

  def test_maxdisk_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 8_589_934_592, container.maxdisk
  end

  # ---------------------------
  # Metadata Attributes
  # ---------------------------

  def test_uptime_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 864_000, container.uptime
  end

  def test_template_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 0, container.template
  end

  def test_tags_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal "prod;web", container.tags
  end

  def test_pool_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal "production", container.pool
  end

  def test_lock_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.lock
  end

  def test_lock_attribute_when_locked
    attrs = @running_container_attrs.merge(lock: "backup")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "backup", container.lock
  end

  # ---------------------------
  # Network I/O Attributes
  # ---------------------------

  def test_netin_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 123_456_789, container.netin
  end

  def test_netout_attribute
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal 987_654_321, container.netout
  end

  # ---------------------------
  # Status Predicate Methods
  # ---------------------------

  def test_running_returns_true_for_running_container
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert container.running?
  end

  def test_running_returns_false_for_stopped_container
    container = Pvectl::Models::Container.new(@stopped_container_attrs)
    refute container.running?
  end

  def test_stopped_returns_true_for_stopped_container
    container = Pvectl::Models::Container.new(@stopped_container_attrs)
    assert container.stopped?
  end

  def test_stopped_returns_false_for_running_container
    container = Pvectl::Models::Container.new(@running_container_attrs)
    refute container.stopped?
  end

  # ---------------------------
  # Template Predicate Method
  # ---------------------------

  def test_template_returns_true_for_template
    container = Pvectl::Models::Container.new(@template_attrs)
    assert container.template?
  end

  def test_template_returns_false_for_regular_container
    container = Pvectl::Models::Container.new(@running_container_attrs)
    refute container.template?
  end

  # ---------------------------
  # Unprivileged Predicate Method
  # ---------------------------

  def test_unprivileged_returns_true_when_unprivileged_is_1
    attrs = @running_container_attrs.merge(unprivileged: 1)
    container = Pvectl::Models::Container.new(attrs)
    assert container.unprivileged?
  end

  def test_unprivileged_returns_false_when_unprivileged_is_0
    attrs = @running_container_attrs.merge(unprivileged: 0)
    container = Pvectl::Models::Container.new(attrs)
    refute container.unprivileged?
  end

  def test_unprivileged_returns_false_when_unprivileged_is_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    refute container.unprivileged?
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
    container = Pvectl::Models::Container.new(string_attrs)
    assert_equal 100, container.vmid
    assert_equal "test", container.name
  end

  # ---------------------------
  # Describe-Only Attributes
  # ---------------------------

  def test_ostype_attribute
    attrs = @running_container_attrs.merge(ostype: "debian")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "debian", container.ostype
  end

  def test_ostype_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.ostype
  end

  def test_arch_attribute
    attrs = @running_container_attrs.merge(arch: "amd64")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "amd64", container.arch
  end

  def test_arch_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.arch
  end

  def test_features_attribute
    attrs = @running_container_attrs.merge(features: "nesting=1,keyctl=1")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "nesting=1,keyctl=1", container.features
  end

  def test_features_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.features
  end

  def test_rootfs_attribute
    attrs = @running_container_attrs.merge(rootfs: "local-lvm:vm-100-disk-0,size=8G")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "local-lvm:vm-100-disk-0,size=8G", container.rootfs
  end

  def test_rootfs_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.rootfs
  end

  def test_network_interfaces_attribute
    interfaces = [{ name: "eth0", bridge: "vmbr0", ip: "192.168.1.100/24" }]
    attrs = @running_container_attrs.merge(network_interfaces: interfaces)
    container = Pvectl::Models::Container.new(attrs)
    assert_equal interfaces, container.network_interfaces
  end

  def test_network_interfaces_defaults_to_empty_array
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_equal [], container.network_interfaces
  end

  def test_description_attribute
    attrs = @running_container_attrs.merge(description: "Production web frontend container")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "Production web frontend container", container.description
  end

  def test_description_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.description
  end

  def test_hostname_attribute
    attrs = @running_container_attrs.merge(hostname: "web-frontend.example.com")
    container = Pvectl::Models::Container.new(attrs)
    assert_equal "web-frontend.example.com", container.hostname
  end

  def test_hostname_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.hostname
  end

  def test_pid_attribute
    attrs = @running_container_attrs.merge(pid: 12345)
    container = Pvectl::Models::Container.new(attrs)
    assert_equal 12345, container.pid
  end

  def test_pid_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.pid
  end

  def test_ha_attribute
    ha_state = { managed: 1, state: "started" }
    attrs = @running_container_attrs.merge(ha: ha_state)
    container = Pvectl::Models::Container.new(attrs)
    assert_equal ha_state, container.ha
  end

  def test_ha_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.ha
  end

  def test_unprivileged_attribute
    attrs = @running_container_attrs.merge(unprivileged: 1)
    container = Pvectl::Models::Container.new(attrs)
    assert_equal 1, container.unprivileged
  end

  def test_unprivileged_attribute_defaults_to_nil
    container = Pvectl::Models::Container.new(@running_container_attrs)
    assert_nil container.unprivileged
  end

  # ---------------------------
  # Type Attribute
  # ---------------------------

  def test_type_returns_lxc_when_set
    ct = Pvectl::Models::Container.new(vmid: 200, type: "lxc")
    assert_equal "lxc", ct.type
  end

  def test_type_returns_nil_when_not_set
    ct = Pvectl::Models::Container.new(vmid: 200)
    assert_nil ct.type
  end
end
