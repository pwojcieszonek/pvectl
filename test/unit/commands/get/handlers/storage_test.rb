# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Storage Tests
# =============================================================================

class GetHandlersStorageTest < Minitest::Test
  # Tests for the Storage resource handler

  def setup
    @storage1 = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      node: "pve-node1",
      disk: 48_318_382_080,
      maxdisk: 107_374_182_400,
      content: "images,rootdir,vztmpl,iso,backup",
      shared: 0
    )

    @storage2 = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      node: "pve-node1",
      disk: 251_274_936_320,
      maxdisk: 536_870_912_000,
      content: "images,rootdir",
      shared: 0
    )

    @storage3 = Pvectl::Models::Storage.new(
      name: "ceph-pool",
      plugintype: "rbd",
      status: "available",
      node: nil,
      disk: 955_630_223_360,
      maxdisk: 2_199_023_255_552,
      content: "images",
      shared: 1
    )

    @storage4 = Pvectl::Models::Storage.new(
      name: "nfs-backup",
      plugintype: "nfs",
      status: "available",
      node: nil,
      disk: 1_288_490_188_800,
      maxdisk: 4_398_046_511_104,
      content: "backup,iso",
      shared: 1
    )

    @all_storage = [@storage1, @storage2, @storage3, @storage4]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Storage
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Storage.new
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
    assert_respond_to handler, :describe
  end

  # ---------------------------
  # list() Method - Basic
  # ---------------------------

  def test_list_returns_all_storage_from_repository
    handler = create_handler_with_mock_repo(@all_storage)

    storage_pools = handler.list

    assert_equal 4, storage_pools.length
    assert storage_pools.all? { |s| s.is_a?(Pvectl::Models::Storage) }
  end

  def test_list_with_name_filter
    handler = create_handler_with_mock_repo(@all_storage)

    storage_pools = handler.list(name: "local")

    assert_equal 1, storage_pools.length
    assert_equal "local", storage_pools.first.name
  end

  def test_list_returns_empty_array_when_no_name_match
    handler = create_handler_with_mock_repo(@all_storage)

    storage_pools = handler.list(name: "nonexistent")

    assert_empty storage_pools
  end

  # ---------------------------
  # list() Method - Node Filter
  # ---------------------------

  def test_list_with_node_filter
    handler = create_handler_with_mock_repo(@all_storage)

    storage_pools = handler.list(node: "pve-node1")

    # Should include local storages and shared storage
    assert_equal 4, storage_pools.length
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_storage_presenter
    handler = Pvectl::Commands::Get::Handlers::Storage.new(repository: MockRepository.new([]))

    presenter = handler.presenter

    assert_instance_of Pvectl::Presenters::Storage, presenter
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_storage_from_repository
    handler = create_handler_with_mock_repo(@all_storage)

    storage = handler.describe(name: "local")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "local", storage.name
  end

  def test_describe_raises_argument_error_for_nil_name
    handler = create_handler_with_mock_repo(@all_storage)

    assert_raises ArgumentError do
      handler.describe(name: nil)
    end
  end

  def test_describe_raises_argument_error_for_empty_name
    handler = create_handler_with_mock_repo(@all_storage)

    assert_raises ArgumentError do
      handler.describe(name: "")
    end
  end

  def test_describe_raises_resource_not_found_error_when_storage_not_found
    handler = create_handler_with_mock_repo(@all_storage)

    error = assert_raises Pvectl::ResourceNotFoundError do
      handler.describe(name: "nonexistent")
    end

    assert_equal "Storage not found: nonexistent", error.message
  end

  def test_describe_argument_error_message
    handler = create_handler_with_mock_repo(@all_storage)

    error = assert_raises ArgumentError do
      handler.describe(name: nil)
    end

    assert_equal "Invalid storage name", error.message
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_storages
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "storages", Pvectl::Commands::Get::Handlers::Storage, aliases: ["storage", "stor"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("storages")
  end

  def test_handler_is_registered_with_storage_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "storages", Pvectl::Commands::Get::Handlers::Storage, aliases: ["storage", "stor"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("storage")
  end

  def test_handler_is_registered_with_stor_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "storages", Pvectl::Commands::Get::Handlers::Storage, aliases: ["storage", "stor"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("stor")
  end

  def test_registry_returns_storage_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "storages", Pvectl::Commands::Get::Handlers::Storage, aliases: ["storage", "stor"]
    )

    handler = Pvectl::Commands::Get::ResourceRegistry.for("storages")

    assert_instance_of Pvectl::Commands::Get::Handlers::Storage, handler
  end

  # ---------------------------
  # describe() Method with node parameter
  # ---------------------------

  def test_describe_with_node_returns_storage_for_specific_node
    handler = create_handler_with_mock_repo_v2(@all_storage)

    storage = handler.describe(name: "local", node: "pve-node1")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "local", storage.name
    assert_equal "pve-node1", storage.node
  end

  def test_describe_without_node_for_local_storage_returns_instances
    # Setup: local storage with multiple instances
    local_node1 = Pvectl::Models::Storage.new(
      name: "local", plugintype: "dir", node: "pve-node1", shared: 0
    )
    local_node2 = Pvectl::Models::Storage.new(
      name: "local", plugintype: "dir", node: "pve-node2", shared: 0
    )
    handler = create_handler_with_mock_repo_v2([local_node1, local_node2])

    result = handler.describe(name: "local")

    # Should return array of instances when multiple exist and no node specified
    assert_instance_of Array, result
    assert_equal 2, result.length
  end

  def test_describe_without_node_for_shared_storage_returns_single_model
    # Setup: shared storage (single instance)
    handler = create_handler_with_mock_repo_v2([@storage3])

    result = handler.describe(name: "ceph-pool")

    # Shared storage should return single model (not array)
    assert_instance_of Pvectl::Models::Storage, result
  end

  def test_describe_with_invalid_node_raises_resource_not_found_error
    handler = create_handler_with_mock_repo_v2(@all_storage)

    error = assert_raises Pvectl::ResourceNotFoundError do
      handler.describe(name: "local", node: "nonexistent-node")
    end

    assert_equal "Storage 'local' not found on node 'nonexistent-node'", error.message
  end

  def test_describe_without_node_for_single_local_storage_returns_model
    # Setup: local storage with single instance
    single_local = Pvectl::Models::Storage.new(
      name: "local", plugintype: "dir", node: "pve-node1", shared: 0
    )
    handler = create_handler_with_mock_repo_v2([single_local])

    result = handler.describe(name: "local")

    # Single instance should return model directly
    assert_instance_of Pvectl::Models::Storage, result
  end

  private

  # Creates a handler with a mock repository returning given storage pools
  def create_handler_with_mock_repo(storage_pools)
    mock_repo = MockRepository.new(storage_pools)
    Pvectl::Commands::Get::Handlers::Storage.new(repository: mock_repo)
  end

  # Creates a handler with a mock repository that supports list_instances and node parameter
  def create_handler_with_mock_repo_v2(storage_pools)
    mock_repo = MockRepositoryV2.new(storage_pools)
    Pvectl::Commands::Get::Handlers::Storage.new(repository: mock_repo)
  end

  # Simple mock repository for testing
  class MockRepository
    def initialize(storage_pools)
      @storage_pools = storage_pools
    end

    def list(node: nil)
      @storage_pools.dup
    end

    def describe(name, node: nil)
      @storage_pools.find { |s| s.name == name }
    end

    def list_instances(name)
      @storage_pools.select { |s| s.name == name }
    end
  end

  # Mock repository with full support for node parameter
  class MockRepositoryV2
    def initialize(storage_pools)
      @storage_pools = storage_pools
    end

    def list(node: nil)
      @storage_pools.dup
    end

    def list_instances(name)
      @storage_pools.select { |s| s.name == name }
    end

    def describe(name, node: nil)
      if node
        @storage_pools.find { |s| s.name == name && s.node == node }
      else
        @storage_pools.find { |s| s.name == name }
      end
    end
  end
end
