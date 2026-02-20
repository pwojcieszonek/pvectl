# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Node Tests
# =============================================================================

class RepositoriesNodeTest < Minitest::Test
  # Tests for the Node repository

  def setup
    # NOTE: proxmox-api gem returns Hashes with symbol keys
    @mock_nodes_response = [
      {
        node: "pve-node1",
        status: "online",
        cpu: 0.23,
        maxcpu: 32,
        mem: 48_535_150_182,
        maxmem: 137_438_953_472,
        disk: 1_288_490_188_800,
        maxdisk: 4_398_046_511_104,
        uptime: 3_898_800,
        level: "c"
      },
      {
        node: "pve-node2",
        status: "online",
        cpu: 0.67,
        maxcpu: 32,
        mem: 95_695_953_920,
        maxmem: 137_438_953_472,
        disk: 3_006_477_107_200,
        maxdisk: 4_398_046_511_104,
        uptime: 3_898_800,
        level: "c"
      },
      {
        node: "pve-node3",
        status: "online",
        cpu: 0.12,
        maxcpu: 16,
        mem: 34_359_738_368,
        maxmem: 68_719_476_736,
        disk: 536_870_912_000,
        maxdisk: 2_199_023_255_552,
        uptime: 1_058_400,
        level: "c"
      },
      {
        node: "pve-node4",
        status: "offline",
        cpu: nil,
        maxcpu: 16,
        mem: nil,
        maxmem: 68_719_476_736,
        disk: nil,
        maxdisk: 2_199_023_255_552,
        uptime: nil,
        level: "c"
      }
    ]

    @mock_resources_response = [
      { node: "pve-node1", type: "qemu", vmid: 100 },
      { node: "pve-node1", type: "qemu", vmid: 101 },
      { node: "pve-node1", type: "lxc", vmid: 200 },
      { node: "pve-node2", type: "qemu", vmid: 102 },
      { node: "pve-node2", type: "lxc", vmid: 201 },
      { node: "pve-node2", type: "lxc", vmid: 202 },
      { node: "pve-node3", type: "qemu", vmid: 103 }
    ]

    @mock_version_response = {
      version: "8.3.2",
      release: "1",
      kernel: "6.8.12-1-pve"
    }

    @mock_status_response = {
      loadavg: [0.45, 0.52, 0.48],
      swap: {
        used: 0,
        total: 8_589_934_592
      }
    }

    @mock_network_response = [
      {
        iface: "lo",
        type: "loopback",
        address: "127.0.0.1"
      },
      {
        iface: "enp0s31f6",
        type: "eth",
        active: 1
      },
      {
        iface: "vmbr0",
        type: "bridge",
        address: "192.168.1.10",
        cidr: "192.168.1.10/24",
        gateway: "192.168.1.1",
        active: 1
      }
    ]

    # Extended mock responses for describe tests
    @mock_describe_status_response = {
      loadavg: [0.45, 0.52, 0.48],
      swap: { used: 0, total: 8_589_934_592 },
      cpuinfo: {
        cores: 16,
        sockets: 2,
        model: "AMD EPYC 7302 16-Core Processor"
      },
      kversion: "Linux 6.8.12-1-pve #1 SMP",
      uptime: 3_898_800,
      "boot-info": { mode: "efi", secureboot: 0 },
      rootfs: {
        used: 1_288_490_188_800,
        total: 4_398_046_511_104
      }
    }

    @mock_subscription_response = {
      status: "Active",
      level: "c",
      productname: "Proxmox VE Community"
    }

    @mock_dns_response = {
      search: "example.com",
      dns1: "192.168.1.1",
      dns2: "8.8.8.8",
      dns3: "8.8.4.4"
    }

    @mock_time_response = {
      timezone: "Europe/Warsaw",
      localtime: 1705326765,
      time: 1705326765
    }

    @mock_services_response = [
      { service: "pve-cluster", state: "running", desc: "Proxmox VE Cluster Service" },
      { service: "pvedaemon", state: "running", desc: "Proxmox VE API Daemon" },
      { service: "ceph-mon", state: "stopped", desc: "Ceph Monitor" }
    ]

    @mock_storage_response = [
      { storage: "local", type: "dir", total: 107_374_182_400, used: 53_687_091_200, avail: 53_687_091_200, enabled: 1 },
      { storage: "local-lvm", type: "lvmthin", total: 536_870_912_000, used: 268_435_456_000, avail: 268_435_456_000, enabled: 1 }
    ]

    @mock_disks_response = [
      { devpath: "/dev/sda", model: "Samsung SSD 870", size: 536_870_912_000, type: "SSD", health: "PASSED" },
      { devpath: "/dev/sdb", model: "WDC WD4003FFBX", size: 4_398_046_511_104, type: "HDD", health: "PASSED" }
    ]

    @mock_qemu_cpu_response = [
      { name: "host", vendor: "unknown", custom: 0 },
      { name: "max", vendor: "unknown", custom: 0 },
      { name: "kvm64", vendor: "unknown", custom: 0 }
    ]

    @mock_qemu_machines_response = [
      { id: "pc-q35-8.1", type: "q35", version: "8.1" },
      { id: "pc-i440fx-8.1", type: "i440fx", version: "8.1" }
    ]

    @mock_apt_versions_response = [
      { Package: "pve-manager", CurrentVersion: "8.3.1", AvailableVersion: "8.3.2" },
      { Package: "proxmox-ve", CurrentVersion: "8.3.1", AvailableVersion: "8.3.2" },
      { Package: "pve-kernel-6.8", CurrentVersion: "6.8.12-1", AvailableVersion: "6.8.12-2" },
      { Package: "qemu-server", CurrentVersion: "8.2.1", AvailableVersion: "8.2.1" },
      { Package: "lxc-pve", CurrentVersion: "6.0.0-1", AvailableVersion: "6.0.0-2" },
      { Package: "ceph", CurrentVersion: "18.2.0-1", AvailableVersion: "18.2.1-1" }
    ]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_node_repository_class_exists
    assert_kind_of Class, Pvectl::Repositories::Node
  end

  def test_node_repository_inherits_from_base
    assert Pvectl::Repositories::Node < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list() Method - Basic
  # ---------------------------

  def test_list_returns_array_of_node_models
    repo = create_repo_with_mock_responses

    nodes = repo.list

    assert_kind_of Array, nodes
    assert nodes.all? { |n| n.is_a?(Pvectl::Models::Node) }
  end

  def test_list_returns_correct_number_of_nodes
    repo = create_repo_with_mock_responses

    nodes = repo.list

    assert_equal 4, nodes.length
  end

  def test_list_returns_empty_array_when_api_returns_empty
    repo = create_repo_with_mock_responses(nodes: [], resources: [])

    nodes = repo.list

    assert_empty nodes
  end

  def test_list_maps_basic_node_attributes_correctly
    repo = create_repo_with_mock_responses

    node = repo.list.find { |n| n.name == "pve-node1" }

    assert_equal "pve-node1", node.name
    assert_equal "online", node.status
    assert_equal 0.23, node.cpu
    assert_equal 32, node.maxcpu
    assert_equal 48_535_150_182, node.mem
    assert_equal 137_438_953_472, node.maxmem
    assert_equal 1_288_490_188_800, node.disk
    assert_equal 4_398_046_511_104, node.maxdisk
    assert_equal 3_898_800, node.uptime
    assert_equal "c", node.level
  end

  # ---------------------------
  # list() Method - Guest Counts
  # ---------------------------

  def test_list_includes_guest_counts
    repo = create_repo_with_mock_responses

    node1 = repo.list.find { |n| n.name == "pve-node1" }
    node2 = repo.list.find { |n| n.name == "pve-node2" }
    node3 = repo.list.find { |n| n.name == "pve-node3" }
    node4 = repo.list.find { |n| n.name == "pve-node4" }

    # pve-node1: 2 VMs, 1 CT
    assert_equal 2, node1.guests_vms
    assert_equal 1, node1.guests_cts

    # pve-node2: 1 VM, 2 CTs
    assert_equal 1, node2.guests_vms
    assert_equal 2, node2.guests_cts

    # pve-node3: 1 VM, 0 CTs
    assert_equal 1, node3.guests_vms
    assert_equal 0, node3.guests_cts

    # pve-node4: 0 VMs, 0 CTs
    assert_equal 0, node4.guests_vms
    assert_equal 0, node4.guests_cts
  end

  # ---------------------------
  # list() Method - include_details
  # ---------------------------

  def test_list_without_details_does_not_include_version
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: false).find { |n| n.name == "pve-node1" }

    assert_nil node.version
    assert_nil node.kernel
  end

  def test_list_with_details_includes_version_for_online_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal "8.3.2", node.version
    assert_equal "6.8.12-1-pve", node.kernel
  end

  def test_list_with_details_includes_load_for_online_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal [0.45, 0.52, 0.48], node.loadavg
  end

  def test_list_with_details_includes_swap_for_online_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal 0, node.swap_used
    assert_equal 8_589_934_592, node.swap_total
  end

  def test_list_with_details_skips_details_for_offline_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node4" }

    assert_nil node.version
    assert_nil node.kernel
    assert_nil node.loadavg
  end

  # ---------------------------
  # get() Method
  # ---------------------------

  def test_get_returns_node_by_name
    repo = create_repo_with_mock_responses

    node = repo.get("pve-node1")

    assert_instance_of Pvectl::Models::Node, node
    assert_equal "pve-node1", node.name
  end

  def test_get_returns_nil_when_name_not_found
    repo = create_repo_with_mock_responses

    node = repo.get("nonexistent")

    assert_nil node
  end

  def test_get_with_include_details
    repo = create_repo_with_mock_responses

    node = repo.get("pve-node1", include_details: true)

    assert_equal "8.3.2", node.version
  end

  # ---------------------------
  # list() Method - IP Address (Network)
  # ---------------------------

  def test_list_with_details_includes_ip_for_online_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal "192.168.1.10", node.ip
  end

  def test_list_with_details_skips_ip_for_offline_nodes
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: true).find { |n| n.name == "pve-node4" }

    assert_nil node.ip
  end

  def test_list_without_details_does_not_include_ip
    repo = create_repo_with_mock_responses

    node = repo.list(include_details: false).find { |n| n.name == "pve-node1" }

    assert_nil node.ip
  end

  def test_list_with_details_handles_network_api_error
    repo = create_repo_with_mock_responses(network_error: true)

    # Should not raise, just return nil for IP
    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_nil node.ip
    # Other details should still be fetched
    assert_equal "8.3.2", node.version
  end

  def test_list_with_details_returns_nil_ip_when_no_gateway_interface
    network_no_gateway = [
      { iface: "lo", type: "loopback", address: "127.0.0.1" },
      { iface: "vmbr0", type: "bridge", address: "192.168.1.10", cidr: "192.168.1.10/24" }
    ]
    repo = create_repo_with_mock_responses(network: network_no_gateway)

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_nil node.ip
  end

  def test_list_with_details_strips_cidr_suffix_from_ip
    network_with_cidr = [
      { iface: "vmbr0", type: "bridge", address: "10.0.0.5/24", gateway: "10.0.0.1" }
    ]
    repo = create_repo_with_mock_responses(network: network_with_cidr)

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal "10.0.0.5", node.ip
  end

  def test_list_with_details_uses_cidr_field_when_address_missing
    network_with_only_cidr = [
      { iface: "vmbr0", type: "bridge", cidr: "172.16.0.1/16", gateway: "172.16.0.254" }
    ]
    repo = create_repo_with_mock_responses(network: network_with_only_cidr)

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    assert_equal "172.16.0.1", node.ip
  end

  def test_list_with_details_finds_first_interface_with_gateway
    network_multiple_gateways = [
      { iface: "vmbr0", type: "bridge", address: "192.168.1.10", gateway: "192.168.1.1" },
      { iface: "vmbr1", type: "bridge", address: "10.0.0.1", gateway: "10.0.0.254" }
    ]
    repo = create_repo_with_mock_responses(network: network_multiple_gateways)

    node = repo.list(include_details: true).find { |n| n.name == "pve-node1" }

    # Should return the first interface with gateway
    assert_equal "192.168.1.10", node.ip
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_node_model
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_instance_of Pvectl::Models::Node, node
    assert_equal "pve-node1", node.name
  end

  def test_describe_returns_nil_for_nonexistent_node
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("nonexistent")

    assert_nil node
  end

  def test_describe_includes_subscription_data
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal "Active", node.subscription[:status]
    assert_equal "c", node.subscription[:level]
  end

  def test_describe_includes_dns_data
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal "example.com", node.dns[:search]
    assert_equal "192.168.1.1", node.dns[:dns1]
  end

  def test_describe_includes_time_data
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal "Europe/Warsaw", node.time_info[:timezone]
    assert_equal 1705326765, node.time_info[:localtime]
  end

  def test_describe_includes_services
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.services
    assert node.services.any? { |s| s[:service] == "pve-cluster" }
  end

  def test_describe_includes_storage_pools
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.storage_pools
    # After storage-node-refactor, storage_pools are Models::Storage instances
    assert node.storage_pools.any? { |s| s.name == "local" }
  end

  def test_describe_includes_physical_disks
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.physical_disks
    assert node.physical_disks.any? { |d| d[:devpath] == "/dev/sda" }
  end

  def test_describe_includes_qemu_cpu_models
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.qemu_cpu_models
    assert node.qemu_cpu_models.any? { |m| m[:name] == "host" }
  end

  def test_describe_includes_qemu_machines
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.qemu_machines
    assert node.qemu_machines.any? { |m| m[:id] == "pc-q35-8.1" }
  end

  def test_describe_includes_updates_available_count
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal 5, node.updates_available
  end

  def test_describe_includes_cpuinfo
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal "AMD EPYC 7302 16-Core Processor", node.cpuinfo[:model]
    assert_equal 16, node.cpuinfo[:cores]
    assert_equal 2, node.cpuinfo[:sockets]
  end

  def test_describe_includes_boot_info
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal "efi", node.boot_info[:mode]
  end

  def test_describe_includes_rootfs
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_equal 1288490188800, node.rootfs[:used]
    assert_equal 4398046511104, node.rootfs[:total]
  end

  def test_describe_includes_network_interfaces
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.network_interfaces
    assert node.network_interfaces.any? { |i| i[:iface] == "vmbr0" }
  end

  def test_describe_offline_node_returns_basic_info
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node4")

    assert_equal "pve-node4", node.name
    assert_equal "offline", node.status
    assert_equal "Node offline - detailed metrics unavailable", node.offline_note
  end

  def test_describe_offline_node_does_not_fetch_details
    repo = create_describe_repo_with_mock_responses

    node = repo.describe("pve-node4")

    # Offline node should have nil for detailed fields
    assert_nil node.subscription
    assert_nil node.dns
    assert_nil node.time_info
  end

  def test_describe_handles_api_errors_gracefully
    repo = create_describe_repo_with_errors

    node = repo.describe("pve-node1")

    # Should return node with available data, empty arrays for failed endpoints
    assert_instance_of Pvectl::Models::Node, node
    assert_equal [], node.services
    assert_equal [], node.storage_pools
  end

  private

  # Creates a repository with mock responses for describe tests
  def create_describe_repo_with_mock_responses
    mock_connection = DescribeMockConnection.new(
      nodes: @mock_nodes_response,
      resources: @mock_resources_response,
      version: @mock_version_response,
      status: @mock_describe_status_response,
      network: @mock_network_response,
      subscription: @mock_subscription_response,
      dns: @mock_dns_response,
      time: @mock_time_response,
      services: @mock_services_response,
      storage: @mock_storage_response,
      disks: @mock_disks_response,
      qemu_cpu: @mock_qemu_cpu_response,
      qemu_machines: @mock_qemu_machines_response,
      apt_versions: @mock_apt_versions_response
    )

    Pvectl::Repositories::Node.new(mock_connection)
  end

  # Creates a repository that simulates API errors
  def create_describe_repo_with_errors
    mock_connection = DescribeMockConnectionWithErrors.new(
      nodes: @mock_nodes_response,
      resources: @mock_resources_response
    )

    Pvectl::Repositories::Node.new(mock_connection)
  end

  # Creates a repository with mock responses
  def create_repo_with_mock_responses(nodes: nil, resources: nil, network: nil, network_error: false)
    nodes ||= @mock_nodes_response
    resources ||= @mock_resources_response
    network ||= @mock_network_response

    mock_connection = MockConnection.new(
      nodes: nodes,
      resources: resources,
      version: @mock_version_response,
      status: @mock_status_response,
      network: network,
      network_error: network_error
    )

    Pvectl::Repositories::Node.new(mock_connection)
  end

  # Mock connection that returns configurable responses
  class MockConnection
    def initialize(nodes:, resources:, version:, status:, network: nil, network_error: false)
      @nodes = nodes
      @resources = resources
      @version = version
      @status = status
      @network = network
      @network_error = network_error
    end

    def client
      @client ||= MockClient.new(@nodes, @resources, @version, @status, @network, @network_error)
    end
  end

  class MockClient
    def initialize(nodes, resources, version, status, network, network_error)
      @nodes = nodes
      @resources = resources
      @version = version
      @status = status
      @network = network
      @network_error = network_error
    end

    def [](path)
      case path
      when "nodes"
        MockResource.new(@nodes)
      when "cluster/resources"
        MockResource.new(@resources)
      when /^nodes\/(.+)\/version$/
        MockResource.new(@version)
      when /^nodes\/(.+)\/status$/
        MockResource.new(@status)
      when /^nodes\/(.+)\/network$/
        raise StandardError, "Network API error" if @network_error

        MockResource.new(@network)
      else
        MockResource.new([])
      end
    end
  end

  class MockResource
    def initialize(response)
      @response = response
    end

    def get(**_kwargs)
      @response
    end
  end

  # Mock connection for describe tests with all endpoints
  class DescribeMockConnection
    def initialize(nodes:, resources:, version:, status:, network:, subscription:, dns:, time:, services:, storage:, disks:, qemu_cpu:, qemu_machines:, apt_versions:)
      @nodes = nodes
      @resources = resources
      @version = version
      @status = status
      @network = network
      @subscription = subscription
      @dns = dns
      @time = time
      @services = services
      @storage = storage
      @disks = disks
      @qemu_cpu = qemu_cpu
      @qemu_machines = qemu_machines
      @apt_versions = apt_versions
    end

    def client
      @client ||= DescribeMockClient.new(
        @nodes, @resources, @version, @status, @network,
        @subscription, @dns, @time, @services, @storage,
        @disks, @qemu_cpu, @qemu_machines, @apt_versions
      )
    end
  end

  class DescribeMockClient
    def initialize(nodes, resources, version, status, network, subscription, dns, time, services, storage, disks, qemu_cpu, qemu_machines, apt_versions)
      @nodes = nodes
      @resources = resources
      @version = version
      @status = status
      @network = network
      @subscription = subscription
      @dns = dns
      @time = time
      @services = services
      @storage = storage
      @disks = disks
      @qemu_cpu = qemu_cpu
      @qemu_machines = qemu_machines
      @apt_versions = apt_versions
    end

    def [](path)
      case path
      when "nodes"
        MockResource.new(@nodes)
      when "cluster/resources"
        MockResource.new(@resources)
      when /^nodes\/(.+)\/version$/
        MockResource.new(@version)
      when /^nodes\/(.+)\/status$/
        MockResource.new(@status)
      when /^nodes\/(.+)\/network$/
        MockResource.new(@network)
      when /^nodes\/(.+)\/subscription$/
        MockResource.new(@subscription)
      when /^nodes\/(.+)\/dns$/
        MockResource.new(@dns)
      when /^nodes\/(.+)\/time$/
        MockResource.new(@time)
      when /^nodes\/(.+)\/services$/
        MockResource.new(@services)
      when /^nodes\/(.+)\/storage$/
        MockResource.new(@storage)
      when /^nodes\/(.+)\/disks\/list$/
        MockResource.new(@disks)
      when /^nodes\/(.+)\/capabilities\/qemu\/cpu$/
        MockResource.new(@qemu_cpu)
      when /^nodes\/(.+)\/capabilities\/qemu\/machines$/
        MockResource.new(@qemu_machines)
      when /^nodes\/(.+)\/apt\/versions$/
        MockResource.new(@apt_versions)
      else
        MockResource.new([])
      end
    end
  end

  # Mock connection that simulates API errors
  class DescribeMockConnectionWithErrors
    def initialize(nodes:, resources:)
      @nodes = nodes
      @resources = resources
    end

    def client
      @client ||= ErrorMockClient.new(@nodes, @resources)
    end
  end

  class ErrorMockClient
    def initialize(nodes, resources)
      @nodes = nodes
      @resources = resources
    end

    def [](path)
      case path
      when "nodes"
        MockResource.new(@nodes)
      when "cluster/resources"
        MockResource.new(@resources)
      when /^nodes\/(.+)\/version$/
        # Version returns normally
        MockResource.new({ version: "8.3.2", kernel: "6.8.12-1-pve" })
      when /^nodes\/(.+)\/status$/
        # Status returns normally
        MockResource.new({ loadavg: [0.5, 0.5, 0.5], swap: { used: 0, total: 8_000_000_000 } })
      else
        # Other endpoints throw errors
        ErrorMockResource.new
      end
    end
  end

  class ErrorMockResource
    def get(**_kwargs)
      raise StandardError, "API endpoint not available"
    end
  end
end

# =============================================================================
# Repositories::Node Storage Pool Refactor Tests
# NEW TESTS FOR STORAGE-NODE-REFACTOR
# =============================================================================

class RepositoriesNodeStorageRefactorTest < Minitest::Test
  # Tests for the refactored fetch_storage_pools that uses Repositories::Storage

  def setup
    @mock_nodes_response = [
      { node: "pve-node1", status: "online", cpu: 0.23, maxcpu: 32 }
    ]

    @mock_resources_response = []

    @mock_storage_models = [
      Pvectl::Models::Storage.new(
        name: "local",
        plugintype: "dir",
        node: "pve-node1",
        disk: 48_318_382_080,
        maxdisk: 107_374_182_400,
        avail: 59_055_800_320,
        enabled: 1,
        active: 1,
        status: "available"
      ),
      Pvectl::Models::Storage.new(
        name: "local-lvm",
        plugintype: "lvmthin",
        node: "pve-node1",
        disk: 251_274_936_320,
        maxdisk: 536_870_912_000,
        avail: 285_595_975_680,
        enabled: 1,
        active: 1,
        status: "available"
      )
    ]
  end

  # ---------------------------
  # describe() with Storage Repository Delegation
  # ---------------------------

  def test_describe_returns_storage_pools_as_storage_models
    repo = create_repo_with_storage_delegation

    node = repo.describe("pve-node1")

    assert_kind_of Array, node.storage_pools
    assert node.storage_pools.all? { |s| s.is_a?(Pvectl::Models::Storage) }
  end

  def test_describe_storage_pools_count_matches_repository_response
    repo = create_repo_with_storage_delegation

    node = repo.describe("pve-node1")

    assert_equal 2, node.storage_pools.length
  end

  def test_describe_storage_pools_have_correct_attributes
    repo = create_repo_with_storage_delegation

    node = repo.describe("pve-node1")
    local = node.storage_pools.find { |s| s.name == "local" }

    assert_equal "local", local.name
    assert_equal "dir", local.plugintype
    assert_equal 107_374_182_400, local.maxdisk
    assert_equal 48_318_382_080, local.disk
    assert_equal 59_055_800_320, local.avail
    assert local.enabled?
  end

  def test_describe_storage_pools_have_node_set
    repo = create_repo_with_storage_delegation

    node = repo.describe("pve-node1")

    node.storage_pools.each do |storage|
      assert_equal "pve-node1", storage.node
    end
  end

  # ---------------------------
  # Dependency Injection for storage_repository
  # ---------------------------

  def test_node_repository_accepts_storage_repository_parameter
    mock_storage_repo = Object.new
    mock_storage_repo.define_singleton_method(:list_for_node) do |_node_name|
      []
    end

    mock_connection = create_basic_mock_connection

    # Should not raise
    repo = Pvectl::Repositories::Node.new(mock_connection, storage_repository: mock_storage_repo)
    assert_instance_of Pvectl::Repositories::Node, repo
  end

  def test_describe_uses_injected_storage_repository
    call_count = 0
    mock_storage_repo = Object.new
    mock_storage_repo.define_singleton_method(:list_for_node) do |node_name|
      call_count += 1
      raise "Wrong node name" unless node_name == "pve-node1"

      []
    end

    mock_connection = create_basic_mock_connection
    repo = Pvectl::Repositories::Node.new(mock_connection, storage_repository: mock_storage_repo)

    repo.describe("pve-node1")

    assert_equal 1, call_count, "storage_repository.list_for_node should be called once"
  end

  # ---------------------------
  # Error Handling in Storage Delegation
  # ---------------------------

  def test_describe_returns_empty_storage_pools_on_storage_repo_error
    mock_storage_repo = Object.new
    mock_storage_repo.define_singleton_method(:list_for_node) do |_node_name|
      raise StandardError, "Storage API error"
    end

    mock_connection = create_basic_mock_connection
    repo = Pvectl::Repositories::Node.new(mock_connection, storage_repository: mock_storage_repo)

    node = repo.describe("pve-node1")

    # Should not raise, return empty array
    assert_equal [], node.storage_pools
  end

  private

  # Creates a basic mock connection for node repository
  def create_basic_mock_connection
    nodes = @mock_nodes_response
    resources = @mock_resources_response

    mock_client = Object.new

    mock_client.define_singleton_method(:[]) do |path|
      res = Object.new
      res.define_singleton_method(:get) do |**_kwargs|
        case path
        when "nodes"
          nodes
        when "cluster/resources"
          resources
        when /^nodes\/(.+)\/version$/
          { version: "8.3.2", kernel: "6.8.12-1-pve" }
        when /^nodes\/(.+)\/status$/
          { loadavg: [0.5, 0.5, 0.5], swap: { used: 0, total: 8_000_000_000 } }
        when /^nodes\/(.+)\/network$/
          []
        else
          []
        end
      end
      res
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }
    mock_connection
  end

  # Creates a repository with mock storage repository delegation
  def create_repo_with_storage_delegation
    storage_models = @mock_storage_models

    mock_storage_repo = Object.new
    mock_storage_repo.define_singleton_method(:list_for_node) do |_node_name|
      storage_models
    end

    mock_connection = create_basic_mock_connection
    Pvectl::Repositories::Node.new(mock_connection, storage_repository: mock_storage_repo)
  end
end
