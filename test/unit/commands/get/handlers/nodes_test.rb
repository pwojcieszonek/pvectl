# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Nodes Tests
# =============================================================================

class GetHandlersNodesTest < Minitest::Test
  # Tests for the Nodes resource handler

  def setup
    @node1 = Pvectl::Models::Node.new(
      name: "pve-node1",
      status: "online",
      cpu: 0.23,
      maxcpu: 32,
      mem: 48_535_150_182,
      maxmem: 137_438_953_472,
      uptime: 3_898_800,
      guests_vms: 28,
      guests_cts: 14
    )

    @node2 = Pvectl::Models::Node.new(
      name: "pve-node2",
      status: "online",
      cpu: 0.67,
      maxcpu: 32,
      mem: 95_695_953_920,
      maxmem: 137_438_953_472,
      uptime: 3_898_800,
      guests_vms: 25,
      guests_cts: 13
    )

    @node3 = Pvectl::Models::Node.new(
      name: "pve-node3",
      status: "online",
      cpu: 0.12,
      maxcpu: 16,
      mem: 34_359_738_368,
      maxmem: 68_719_476_736,
      uptime: 1_058_400,
      guests_vms: 10,
      guests_cts: 5
    )

    @offline_node = Pvectl::Models::Node.new(
      name: "pve-node4",
      status: "offline",
      cpu: nil,
      maxcpu: 16,
      mem: nil,
      maxmem: 68_719_476_736,
      uptime: nil,
      guests_vms: 0,
      guests_cts: 0
    )

    @all_nodes = [@node1, @node2, @node3, @offline_node]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Nodes
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Nodes.new
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  # ---------------------------
  # list() Method - Basic
  # ---------------------------

  def test_list_returns_all_nodes_from_repository
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list

    assert_equal 4, nodes.length
    assert nodes.all? { |n| n.is_a?(Pvectl::Models::Node) }
  end

  def test_list_with_name_filter
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(name: "pve-node1")

    assert_equal 1, nodes.length
    assert_equal "pve-node1", nodes.first.name
  end

  def test_list_returns_empty_array_when_no_name_match
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(name: "nonexistent")

    assert_empty nodes
  end

  # ---------------------------
  # list() Method - Filtering
  # ---------------------------

  def test_list_with_status_filter_online
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(filter: { status: "online" })

    assert_equal 3, nodes.length
    assert nodes.all?(&:online?)
  end

  def test_list_with_status_filter_offline
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(filter: { status: "offline" })

    assert_equal 1, nodes.length
    assert nodes.all?(&:offline?)
  end

  def test_list_with_unknown_filter_ignores_it
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(filter: { unknown_field: "value" })

    # Should return all nodes since filter is not recognized
    assert_equal 4, nodes.length
  end

  # ---------------------------
  # list() Method - Sorting
  # ---------------------------

  def test_list_with_sort_by_name
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "name")

    names = nodes.map(&:name)
    assert_equal %w[pve-node1 pve-node2 pve-node3 pve-node4], names
  end

  def test_list_with_sort_by_cpu_descending
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "cpu")

    # CPU sort is descending, node2 has highest CPU (0.67)
    assert_equal "pve-node2", nodes.first.name
  end

  def test_list_with_sort_by_memory_descending
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "memory")

    # Memory sort is descending, node2 has highest memory
    assert_equal "pve-node2", nodes.first.name
  end

  def test_list_with_sort_by_guests_descending
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "guests")

    # Guests sort is descending, node1 has 42 guests
    assert_equal "pve-node1", nodes.first.name
  end

  def test_list_with_sort_by_uptime_descending
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "uptime")

    # Uptime sort is descending, nodes 1 and 2 have same uptime
    assert_includes ["pve-node1", "pve-node2"], nodes.first.name
  end

  def test_sort_by_disk_sorts_by_disk_usage_descending
    node_low_disk = Pvectl::Models::Node.new(
      name: "pve-low", status: "online", cpu: 0.1, maxcpu: 8,
      mem: 1_000_000, maxmem: 8_000_000, uptime: 100,
      disk: 10_000_000, maxdisk: 100_000_000,
      guests_vms: 1, guests_cts: 0
    )
    node_high_disk = Pvectl::Models::Node.new(
      name: "pve-high", status: "online", cpu: 0.1, maxcpu: 8,
      mem: 1_000_000, maxmem: 8_000_000, uptime: 100,
      disk: 90_000_000, maxdisk: 100_000_000,
      guests_vms: 1, guests_cts: 0
    )

    mock_repo = Minitest::Mock.new
    mock_repo.expect :list, [node_low_disk, node_high_disk], [], include_details: true

    handler = Pvectl::Commands::Get::Handlers::Nodes.new(repository: mock_repo)
    result = handler.list(sort: "disk")

    assert_equal "pve-high", result[0].name
    assert_equal "pve-low", result[1].name
    mock_repo.verify
  end

  def test_list_with_unknown_sort_returns_original_order
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(sort: "unknown_field")

    # Should return nodes in original order
    assert_equal 4, nodes.length
  end

  # ---------------------------
  # list() Method - Combined
  # ---------------------------

  def test_list_with_filter_and_sort
    handler = create_handler_with_mock_repo(@all_nodes)

    nodes = handler.list(filter: { status: "online" }, sort: "memory")

    assert_equal 3, nodes.length
    assert nodes.all?(&:online?)
    # First should be node2 (highest memory among online nodes)
    assert_equal "pve-node2", nodes.first.name
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_node_presenter
    handler = Pvectl::Commands::Get::Handlers::Nodes.new(repository: MockRepository.new([]))

    presenter = handler.presenter

    assert_instance_of Pvectl::Presenters::Node, presenter
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_nodes
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/nodes.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("nodes")
  end

  def test_handler_is_registered_with_node_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/nodes.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("node")
  end

  def test_registry_returns_nodes_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/nodes.rb", __FILE__)

    handler = Pvectl::Commands::Get::ResourceRegistry.for("nodes")

    assert_instance_of Pvectl::Commands::Get::Handlers::Nodes, handler
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_single_node_model
    handler = create_handler_with_describe_mock_repo

    node = handler.describe(name: "pve-node1")

    assert_instance_of Pvectl::Models::Node, node
    assert_equal "pve-node1", node.name
  end

  def test_describe_raises_error_for_nonexistent_node
    handler = create_handler_with_describe_mock_repo

    error = assert_raises(Pvectl::ResourceNotFoundError) do
      handler.describe(name: "nonexistent")
    end

    assert_includes error.message, "Node not found: nonexistent"
  end

  def test_describe_calls_repository_describe
    mock_repo = MockDescribeRepository.new
    handler = Pvectl::Commands::Get::Handlers::Nodes.new(repository: mock_repo)

    handler.describe(name: "pve-node1")

    assert mock_repo.describe_called
    assert_equal "pve-node1", mock_repo.last_describe_name
  end

  # ---------------------------
  # describe() Method - Input Validation
  # ---------------------------

  def test_describe_rejects_invalid_node_name_with_path_traversal
    handler = create_handler_with_describe_mock_repo

    assert_raises(ArgumentError) do
      handler.describe(name: "../etc/passwd")
    end
  end

  def test_describe_rejects_invalid_node_name_with_command_injection
    handler = create_handler_with_describe_mock_repo

    assert_raises(ArgumentError) do
      handler.describe(name: "node;rm -rf /")
    end
  end

  def test_describe_rejects_empty_node_name
    handler = create_handler_with_describe_mock_repo

    assert_raises(ArgumentError) do
      handler.describe(name: "")
    end
  end

  def test_describe_rejects_nil_node_name
    handler = create_handler_with_describe_mock_repo

    assert_raises(ArgumentError) do
      handler.describe(name: nil)
    end
  end

  def test_describe_accepts_valid_node_name_with_hyphen
    handler = create_handler_with_describe_mock_repo

    node = handler.describe(name: "pve-node1")

    assert_instance_of Pvectl::Models::Node, node
  end

  def test_describe_accepts_simple_alphanumeric_name
    handler = create_handler_with_describe_mock_repo

    node = handler.describe(name: "pve1")

    assert_instance_of Pvectl::Models::Node, node
  end

  private

  # Creates a handler with a mock repository returning given nodes
  def create_handler_with_mock_repo(nodes)
    mock_repo = MockRepository.new(nodes)
    Pvectl::Commands::Get::Handlers::Nodes.new(repository: mock_repo)
  end

  # Simple mock repository for testing
  class MockRepository
    def initialize(nodes)
      @nodes = nodes
    end

    def list(include_details: false)
      @nodes.dup
    end
  end

  # Creates a handler with a describe-capable mock repo
  def create_handler_with_describe_mock_repo
    mock_repo = MockDescribeRepository.new
    Pvectl::Commands::Get::Handlers::Nodes.new(repository: mock_repo)
  end

  # Mock repository with describe method
  class MockDescribeRepository
    attr_reader :describe_called, :last_describe_name

    def initialize
      @describe_called = false
      @last_describe_name = nil
    end

    def list(include_details: false)
      [
        Pvectl::Models::Node.new(name: "pve-node1", status: "online"),
        Pvectl::Models::Node.new(name: "pve-node2", status: "online")
      ]
    end

    def describe(name)
      @describe_called = true
      @last_describe_name = name

      return nil if name == "nonexistent"

      Pvectl::Models::Node.new(
        name: name,
        status: "online",
        cpu: 0.23,
        maxcpu: 32,
        mem: 48_535_150_182,
        maxmem: 137_438_953_472,
        uptime: 3_898_800,
        version: "8.3.2",
        kernel: "6.8.12-1-pve",
        subscription: { status: "Active", level: "c" },
        dns: { search: "example.com", dns1: "192.168.1.1" },
        services: [{ service: "pve-cluster", state: "running" }]
      )
    end
  end
end
