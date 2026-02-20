# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Containers Tests
# =============================================================================

class GetHandlersContainersTest < Minitest::Test
  # Tests for the Containers resource handler

  def setup
    @container1 = Pvectl::Models::Container.new(
      vmid: 100,
      name: "web-frontend-1",
      status: "running",
      node: "pve-node1"
    )

    @container2 = Pvectl::Models::Container.new(
      vmid: 101,
      name: "web-frontend-2",
      status: "running",
      node: "pve-node2"
    )

    @container3 = Pvectl::Models::Container.new(
      vmid: 200,
      name: "dev-env-alice",
      status: "stopped",
      node: "pve-node3"
    )

    @all_containers = [@container1, @container2, @container3]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Containers
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Containers.new
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  # ---------------------------
  # list() Method
  # ---------------------------

  def test_list_returns_all_containers_from_repository
    handler = create_handler_with_mock_repo(@all_containers)

    containers = handler.list

    assert_equal 3, containers.length
    assert containers.all? { |ct| ct.is_a?(Pvectl::Models::Container) }
  end

  def test_list_with_node_filter_passes_to_repository
    handler = create_handler_with_mock_repo(@all_containers)

    containers = handler.list(node: "pve-node1")

    # Should only return container on pve-node1
    assert_equal 1, containers.length
    assert_equal "pve-node1", containers.first.node
  end

  def test_list_with_name_filter
    handler = create_handler_with_mock_repo(@all_containers)

    containers = handler.list(name: "web-frontend-1")

    assert_equal 1, containers.length
    assert_equal "web-frontend-1", containers.first.name
  end

  def test_list_with_node_and_name_filter
    # Create test data with two containers on same node
    ct1_node1 = Pvectl::Models::Container.new(vmid: 100, name: "web-frontend-1", status: "running", node: "pve-node1")
    ct2_node1 = Pvectl::Models::Container.new(vmid: 102, name: "api-server-1", status: "running", node: "pve-node1")
    all_containers = [ct1_node1, ct2_node1, @container2, @container3]

    handler = create_handler_with_mock_repo(all_containers)

    containers = handler.list(node: "pve-node1", name: "web-frontend-1")

    assert_equal 1, containers.length
    assert_equal "web-frontend-1", containers.first.name
  end

  def test_list_returns_empty_array_when_no_match
    handler = create_handler_with_mock_repo(@all_containers)

    containers = handler.list(name: "nonexistent")

    assert_empty containers
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_container_presenter
    handler = Pvectl::Commands::Get::Handlers::Containers.new(repository: MockRepository.new([]))

    presenter = handler.presenter

    assert_instance_of Pvectl::Presenters::Container, presenter
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_containers
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "containers", Pvectl::Commands::Get::Handlers::Containers,
      aliases: ["container", "ct", "cts"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("containers")
  end

  def test_handler_is_registered_with_container_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "containers", Pvectl::Commands::Get::Handlers::Containers,
      aliases: ["container", "ct", "cts"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("container")
  end

  def test_handler_is_registered_with_ct_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "containers", Pvectl::Commands::Get::Handlers::Containers,
      aliases: ["container", "ct", "cts"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("ct")
  end

  def test_handler_is_registered_with_cts_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "containers", Pvectl::Commands::Get::Handlers::Containers,
      aliases: ["container", "ct", "cts"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("cts")
  end

  def test_registry_returns_containers_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "containers", Pvectl::Commands::Get::Handlers::Containers,
      aliases: ["container", "ct", "cts"]
    )

    handler = Pvectl::Commands::Get::ResourceRegistry.for("containers")

    assert_instance_of Pvectl::Commands::Get::Handlers::Containers, handler
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_single_container_model
    handler = create_handler_with_describe_mock_repo

    container = handler.describe(name: "100")

    assert_instance_of Pvectl::Models::Container, container
    assert_equal 100, container.vmid
  end

  def test_describe_raises_error_for_nonexistent_container
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(Pvectl::ResourceNotFoundError) do
      handler.describe(name: "99999")
    end

    assert_includes error.message, "Container not found: 99999"
  end

  def test_describe_calls_repository_describe
    mock_repo = MockDescribeRepository.new
    handler = Pvectl::Commands::Get::Handlers::Containers.new(repository: mock_repo)

    handler.describe(name: "100")

    assert mock_repo.describe_called
    assert_equal 100, mock_repo.last_describe_ctid
  end

  # ---------------------------
  # describe() Method - CTID Validation
  # ---------------------------

  def test_describe_accepts_valid_ctid_100
    handler = create_handler_with_describe_mock_repo

    container = handler.describe(name: "100")

    assert_equal 100, container.vmid
  end

  def test_describe_accepts_valid_ctid_999999999
    handler = create_handler_with_describe_mock_repo

    container = handler.describe(name: "999999999")

    assert_equal 999999999, container.vmid
  end

  def test_describe_rejects_ctid_below_100
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "99")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_ctid_1
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "1")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_ctid_zero
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "0")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_negative_ctid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "-1")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_non_numeric_ctid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "abc")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_empty_ctid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_nil_ctid
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: nil)
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_ctid_with_leading_zero
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "0100")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_ctid_too_long
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "1000000000")
    end

    assert_includes error.message, "Invalid CTID"
  end

  def test_describe_rejects_ctid_with_special_characters
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(ArgumentError) do
      handler.describe(name: "100;rm -rf")
    end

    assert_includes error.message, "Invalid CTID"
  end

  # ---------------------------
  # list() Method - Sorting
  # ---------------------------

  def test_list_with_sort_by_name
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "charlie", status: "running", node: "pve1"),
      Pvectl::Models::Container.new(vmid: 101, name: "alpha", status: "running", node: "pve1"),
      Pvectl::Models::Container.new(vmid: 102, name: "bravo", status: "running", node: "pve1")
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "name")

    assert_equal %w[alpha bravo charlie], result.map(&:name)
  end

  def test_list_with_sort_by_cpu_descending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "low", status: "running", node: "pve1", cpu: 0.1),
      Pvectl::Models::Container.new(vmid: 101, name: "high", status: "running", node: "pve1", cpu: 0.9)
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "cpu")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_memory_descending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "low", status: "running", node: "pve1", mem: 1_000),
      Pvectl::Models::Container.new(vmid: 101, name: "high", status: "running", node: "pve1", mem: 9_000)
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "memory")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_disk_descending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "low", status: "running", node: "pve1", disk: 100),
      Pvectl::Models::Container.new(vmid: 101, name: "high", status: "running", node: "pve1", disk: 900)
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "disk")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_netin_descending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "low", status: "running", node: "pve1", netin: 100),
      Pvectl::Models::Container.new(vmid: 101, name: "high", status: "running", node: "pve1", netin: 900)
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "netin")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_netout_descending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "low", status: "running", node: "pve1", netout: 100),
      Pvectl::Models::Container.new(vmid: 101, name: "high", status: "running", node: "pve1", netout: 900)
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "netout")

    assert_equal "high", result.first.name
  end

  def test_list_with_sort_by_node_ascending
    cts = [
      Pvectl::Models::Container.new(vmid: 100, name: "ct1", status: "running", node: "pve3"),
      Pvectl::Models::Container.new(vmid: 101, name: "ct2", status: "running", node: "pve1")
    ]
    handler = create_handler_with_mock_repo(cts)

    result = handler.list(sort: "node")

    assert_equal "pve1", result.first.node
  end

  def test_list_with_unknown_sort_returns_original_order
    handler = create_handler_with_mock_repo(@all_containers)

    result = handler.list(sort: "unknown_field")

    assert_equal 3, result.length
  end

  private

  # Creates a handler with a mock repository returning given containers
  def create_handler_with_mock_repo(containers)
    mock_repo = MockRepository.new(containers)
    Pvectl::Commands::Get::Handlers::Containers.new(repository: mock_repo)
  end

  # Simple mock repository for testing
  class MockRepository
    def initialize(containers)
      @containers = containers
    end

    def list(node: nil)
      result = @containers.dup
      result = result.select { |ct| ct.node == node } if node
      result
    end
  end

  # Creates a handler with a describe-capable mock repo
  def create_handler_with_describe_mock_repo
    mock_repo = MockDescribeRepository.new
    Pvectl::Commands::Get::Handlers::Containers.new(repository: mock_repo)
  end

  # Mock repository with describe method
  class MockDescribeRepository
    attr_reader :describe_called, :last_describe_ctid

    def initialize
      @describe_called = false
      @last_describe_ctid = nil
    end

    def list(node: nil)
      [
        Pvectl::Models::Container.new(vmid: 100, name: "web-server", status: "running", node: "pve1"),
        Pvectl::Models::Container.new(vmid: 200, name: "dev-env", status: "stopped", node: "pve2")
      ]
    end

    def describe(ctid)
      @describe_called = true
      @last_describe_ctid = ctid

      return nil unless [100, 999999999].include?(ctid)

      Pvectl::Models::Container.new(
        vmid: ctid,
        name: "test-ct-#{ctid}",
        status: "running",
        node: "pve-node1",
        cpu: 0.12,
        maxcpu: 4,
        mem: 2_254_857_830,
        maxmem: 4_294_967_296,
        uptime: 1_314_000,
        ostype: "debian",
        arch: "amd64",
        unprivileged: 1,
        features: "nesting=1",
        rootfs: "local-lvm:vm-100-disk-0,size=50G",
        network_interfaces: [
          { name: "eth0", bridge: "vmbr0", ip: "192.168.1.100/24", hwaddr: "BC:24:11:AA:BB:CC" }
        ]
      )
    end
  end
end
