# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Vms Tests
# =============================================================================

class GetHandlersVmsTest < Minitest::Test
  # Tests for the VMs resource handler

  def setup
    @vm1 = Pvectl::Models::Vm.new(
      vmid: 100,
      name: "web-frontend-1",
      status: "running",
      node: "pve-node1"
    )

    @vm2 = Pvectl::Models::Vm.new(
      vmid: 101,
      name: "web-frontend-2",
      status: "running",
      node: "pve-node2"
    )

    @vm3 = Pvectl::Models::Vm.new(
      vmid: 200,
      name: "dev-env-alice",
      status: "stopped",
      node: "pve-node3"
    )

    @all_vms = [@vm1, @vm2, @vm3]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Vms
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Vms.new
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  # ---------------------------
  # list() Method
  # ---------------------------

  def test_list_returns_all_vms_from_repository
    handler = create_handler_with_mock_repo(@all_vms)

    vms = handler.list

    assert_equal 3, vms.length
    assert vms.all? { |vm| vm.is_a?(Pvectl::Models::Vm) }
  end

  def test_list_with_node_filter_passes_to_repository
    handler = create_handler_with_mock_repo(@all_vms)

    vms = handler.list(node: "pve-node1")

    # Should only return VM on pve-node1
    assert_equal 1, vms.length
    assert_equal "pve-node1", vms.first.node
  end

  def test_list_with_name_filter
    handler = create_handler_with_mock_repo(@all_vms)

    vms = handler.list(name: "web-frontend-1")

    assert_equal 1, vms.length
    assert_equal "web-frontend-1", vms.first.name
  end

  def test_list_with_node_and_name_filter
    # Create test data with two VMs on same node
    vm1_node1 = Pvectl::Models::Vm.new(vmid: 100, name: "web-frontend-1", status: "running", node: "pve-node1")
    vm2_node1 = Pvectl::Models::Vm.new(vmid: 102, name: "api-server-1", status: "running", node: "pve-node1")
    all_vms = [vm1_node1, vm2_node1, @vm2, @vm3]

    handler = create_handler_with_mock_repo(all_vms)

    vms = handler.list(node: "pve-node1", name: "web-frontend-1")

    assert_equal 1, vms.length
    assert_equal "web-frontend-1", vms.first.name
  end

  def test_list_returns_empty_array_when_no_match
    handler = create_handler_with_mock_repo(@all_vms)

    vms = handler.list(name: "nonexistent")

    assert_empty vms
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_vm_presenter
    handler = Pvectl::Commands::Get::Handlers::Vms.new(repository: MockRepository.new([]))

    presenter = handler.presenter

    assert_instance_of Pvectl::Presenters::Vm, presenter
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_vms
    # Reset and re-register (handler auto-registers on load)
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/vms.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("vms")
  end

  def test_handler_is_registered_with_vm_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/vms.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("vm")
  end

  def test_registry_returns_vms_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/vms.rb", __FILE__)

    handler = Pvectl::Commands::Get::ResourceRegistry.for("vms")

    assert_instance_of Pvectl::Commands::Get::Handlers::Vms, handler
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_single_vm_model
    handler = create_handler_with_describe_mock_repo

    vm = handler.describe(name: "100")

    assert_instance_of Pvectl::Models::Vm, vm
    assert_equal 100, vm.vmid
  end

  def test_describe_raises_error_for_nonexistent_vm
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(Pvectl::ResourceNotFoundError) do
      handler.describe(name: "99999")
    end

    assert_includes error.message, "VM not found: 99999"
  end

  def test_describe_calls_repository_describe
    mock_repo = MockDescribeRepository.new
    handler = Pvectl::Commands::Get::Handlers::Vms.new(repository: mock_repo)

    handler.describe(name: "100")

    assert mock_repo.describe_called
    assert_equal 100, mock_repo.last_describe_vmid
  end

  # ---------------------------
  # describe() Method - VMID Validation
  # ---------------------------

  def test_describe_accepts_valid_vmid_100
    handler = create_handler_with_describe_mock_repo

    vm = handler.describe(name: "100")

    assert_equal 100, vm.vmid
  end

  def test_describe_accepts_valid_vmid_1
    handler = create_handler_with_describe_mock_repo

    vm = handler.describe(name: "1")

    assert_equal 1, vm.vmid
  end

  def test_describe_accepts_valid_vmid_999999999
    handler = create_handler_with_describe_mock_repo

    vm = handler.describe(name: "999999999")

    assert_equal 999999999, vm.vmid
  end

  def test_describe_rejects_vmid_zero
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "0")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_negative_vmid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "-1")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_non_numeric_vmid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "abc")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_empty_vmid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_nil_vmid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: nil)
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_vmid_with_leading_zero
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "0100")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_vmid_too_long
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "1000000000")
    end

    assert_includes error.message, "Invalid VMID"
  end

  def test_describe_rejects_vmid_with_special_characters
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "100;rm -rf")
    end

    assert_includes error.message, "Invalid VMID"
  end

  # ---------------------------
  # list() Method - Sorting
  # ---------------------------

  def test_list_with_sort_by_name
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "charlie", status: "running", node: "pve1"),
      Pvectl::Models::Vm.new(vmid: 2, name: "alpha", status: "running", node: "pve1"),
      Pvectl::Models::Vm.new(vmid: 3, name: "bravo", status: "running", node: "pve1")
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "name")

    assert_equal %w[alpha bravo charlie], result.map(&:name)
  end

  def test_list_with_sort_by_cpu_descending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "low", status: "running", node: "pve1", cpu: 0.1),
      Pvectl::Models::Vm.new(vmid: 2, name: "high", status: "running", node: "pve1", cpu: 0.9)
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "cpu")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_memory_descending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "low", status: "running", node: "pve1", mem: 1_000),
      Pvectl::Models::Vm.new(vmid: 2, name: "high", status: "running", node: "pve1", mem: 9_000)
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "memory")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_disk_descending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "low", status: "running", node: "pve1", disk: 100),
      Pvectl::Models::Vm.new(vmid: 2, name: "high", status: "running", node: "pve1", disk: 900)
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "disk")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_netin_descending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "low", status: "running", node: "pve1", netin: 100),
      Pvectl::Models::Vm.new(vmid: 2, name: "high", status: "running", node: "pve1", netin: 900)
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "netin")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_netout_descending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "low", status: "running", node: "pve1", netout: 100),
      Pvectl::Models::Vm.new(vmid: 2, name: "high", status: "running", node: "pve1", netout: 900)
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "netout")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_node_ascending
    vms = [
      Pvectl::Models::Vm.new(vmid: 1, name: "vm1", status: "running", node: "pve3"),
      Pvectl::Models::Vm.new(vmid: 2, name: "vm2", status: "running", node: "pve1")
    ]
    handler = create_handler_with_mock_repo(vms)

    result = handler.list(sort: "node")

    assert_equal "pve1", result.first.node
  end

  def test_list_with_unknown_sort_returns_original_order
    handler = create_handler_with_mock_repo(@all_vms)

    result = handler.list(sort: "unknown_field")

    assert_equal 3, result.length
  end

  private

  # Creates a handler with a mock repository returning given VMs
  def create_handler_with_mock_repo(vms)
    mock_repo = MockRepository.new(vms)
    Pvectl::Commands::Get::Handlers::Vms.new(repository: mock_repo)
  end

  # Simple mock repository for testing
  class MockRepository
    def initialize(vms)
      @vms = vms
    end

    def list(node: nil)
      result = @vms.dup
      result = result.select { |vm| vm.node == node } if node
      result
    end
  end

  # Creates a handler with a describe-capable mock repo
  def create_handler_with_describe_mock_repo
    mock_repo = MockDescribeRepository.new
    Pvectl::Commands::Get::Handlers::Vms.new(repository: mock_repo)
  end

  # Mock repository with describe method
  class MockDescribeRepository
    attr_reader :describe_called, :last_describe_vmid

    def initialize
      @describe_called = false
      @last_describe_vmid = nil
    end

    def list(node: nil)
      [
        Pvectl::Models::Vm.new(vmid: 100, name: "web-server", status: "running", node: "pve1"),
        Pvectl::Models::Vm.new(vmid: 200, name: "dev-env", status: "stopped", node: "pve2")
      ]
    end

    def describe(vmid)
      @describe_called = true
      @last_describe_vmid = vmid

      return nil unless [1, 100, 999999999].include?(vmid)

      Pvectl::Models::Vm.new(
        vmid: vmid,
        name: "test-vm-#{vmid}",
        status: "running",
        node: "pve-node1",
        cpu: 0.12,
        maxcpu: 4,
        mem: 2_254_857_830,
        maxmem: 4_294_967_296,
        uptime: 1_314_000,
        describe_data: {
          config: { bios: "ovmf", cores: 4 },
          status: { pid: 12345 },
          snapshots: [],
          agent_ips: nil
        }
      )
    end
  end
end
