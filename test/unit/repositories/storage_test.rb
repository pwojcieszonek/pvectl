# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Storage Tests
# =============================================================================

class RepositoriesStorageTest < Minitest::Test
  # Tests for the Storage repository

  def setup
    # NOTE: proxmox-api gem returns Hashes with symbol keys
    @mock_api_response = [
      {
        storage: "local",
        node: "pve-node1",
        type: "storage",
        plugintype: "dir",
        status: "available",
        disk: 48_318_382_080,
        maxdisk: 107_374_182_400,
        content: "images,rootdir,vztmpl,iso,backup",
        shared: 0
      },
      {
        storage: "local",
        node: "pve-node2",
        type: "storage",
        plugintype: "dir",
        status: "available",
        disk: 52_428_800_000,
        maxdisk: 107_374_182_400,
        content: "images,rootdir,vztmpl,iso,backup",
        shared: 0
      },
      {
        storage: "local-lvm",
        node: "pve-node1",
        type: "storage",
        plugintype: "lvmthin",
        status: "available",
        disk: 251_274_936_320,
        maxdisk: 536_870_912_000,
        content: "images,rootdir",
        shared: 0
      },
      {
        storage: "ceph-pool",
        node: "pve-node1",
        type: "storage",
        plugintype: "rbd",
        status: "available",
        disk: 955_630_223_360,
        maxdisk: 2_199_023_255_552,
        content: "images",
        shared: 1
      },
      {
        storage: "ceph-pool",
        node: "pve-node2",
        type: "storage",
        plugintype: "rbd",
        status: "available",
        disk: 955_630_223_360,
        maxdisk: 2_199_023_255_552,
        content: "images",
        shared: 1
      },
      {
        storage: "ceph-pool",
        node: "pve-node3",
        type: "storage",
        plugintype: "rbd",
        status: "available",
        disk: 955_630_223_360,
        maxdisk: 2_199_023_255_552,
        content: "images",
        shared: 1
      },
      {
        storage: "nfs-backup",
        node: "pve-node1",
        type: "storage",
        plugintype: "nfs",
        status: "available",
        disk: 1_288_490_188_800,
        maxdisk: 4_398_046_511_104,
        content: "backup,iso",
        shared: 1
      },
      {
        storage: "nfs-backup",
        node: "pve-node2",
        type: "storage",
        plugintype: "nfs",
        status: "available",
        disk: 1_288_490_188_800,
        maxdisk: 4_398_046_511_104,
        content: "backup,iso",
        shared: 1
      }
    ]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_storage_repository_class_exists
    assert_kind_of Class, Pvectl::Repositories::Storage
  end

  def test_storage_repository_inherits_from_base
    assert Pvectl::Repositories::Storage < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list() Method - Basic
  # ---------------------------

  def test_list_returns_array_of_storage_models
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list

    assert_kind_of Array, storage_pools
    assert storage_pools.all? { |s| s.is_a?(Pvectl::Models::Storage) }
  end

  def test_list_returns_empty_array_when_api_returns_empty
    repo = create_repo_with_mock_response([])

    storage_pools = repo.list

    assert_empty storage_pools
  end

  def test_list_maps_storage_attributes_correctly
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.list.find { |s| s.name == "local" && s.node == "pve-node1" }

    assert_equal "local", storage.name
    assert_equal "dir", storage.plugintype
    assert_equal "available", storage.status
    assert_equal "pve-node1", storage.node
    assert_equal 48_318_382_080, storage.disk
    assert_equal 107_374_182_400, storage.maxdisk
    assert_equal "images,rootdir,vztmpl,iso,backup", storage.content
    assert_equal 0, storage.shared
  end

  # ---------------------------
  # list() Method - Aggregation
  # ---------------------------

  def test_list_aggregates_shared_storage_by_name
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list
    ceph_pools = storage_pools.select { |s| s.name == "ceph-pool" }

    # Shared storage should appear only once (deduplicated)
    assert_equal 1, ceph_pools.length
  end

  def test_list_aggregates_nfs_shared_storage_by_name
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list
    nfs_pools = storage_pools.select { |s| s.name == "nfs-backup" }

    # Shared storage should appear only once
    assert_equal 1, nfs_pools.length
  end

  def test_list_keeps_local_storage_per_node
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list
    local_pools = storage_pools.select { |s| s.name == "local" }

    # Local storage should appear per node (pve-node1 and pve-node2)
    assert_equal 2, local_pools.length
  end

  def test_list_returns_correct_total_count_after_aggregation
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list

    # Expected: 2 local (per node) + 1 local-lvm + 1 ceph-pool (shared) + 1 nfs-backup (shared) = 5
    assert_equal 5, storage_pools.length
  end

  # ---------------------------
  # list() Method - Node Filter
  # ---------------------------

  def test_list_with_node_filter_returns_node_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list(node: "pve-node1")
    local_storage = storage_pools.find { |s| s.name == "local" }

    assert_equal "pve-node1", local_storage.node
  end

  def test_list_with_node_filter_includes_shared_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list(node: "pve-node1")
    ceph_pool = storage_pools.find { |s| s.name == "ceph-pool" }

    # Shared storage should be included regardless of node filter
    refute_nil ceph_pool
  end

  def test_list_with_node_filter_excludes_other_node_local_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    storage_pools = repo.list(node: "pve-node1")
    local_storage_node2 = storage_pools.find { |s| s.name == "local" && s.node == "pve-node2" }

    # Local storage from pve-node2 should not be included
    assert_nil local_storage_node2
  end

  # ---------------------------
  # get() Method
  # ---------------------------

  def test_get_returns_storage_by_name
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.get("ceph-pool")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "ceph-pool", storage.name
  end

  def test_get_returns_nil_when_name_not_found
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.get("nonexistent")

    assert_nil storage
  end

  # ---------------------------
  # Edge Cases
  # ---------------------------

  def test_list_handles_nil_storage_name
    response_with_nil = @mock_api_response + [{ storage: nil, node: "pve-node1" }]
    repo = create_repo_with_mock_response(response_with_nil)

    # Should not raise error
    storage_pools = repo.list

    assert_kind_of Array, storage_pools
  end

  def test_list_handles_hash_response_with_data_key
    # Some API responses wrap data in :data key
    wrapped_response = { data: @mock_api_response }
    repo = create_repo_with_wrapped_response(wrapped_response)

    storage_pools = repo.list

    assert_kind_of Array, storage_pools
    refute_empty storage_pools
  end

  private

  # Creates a repository with a mock connection that returns the given response
  def create_repo_with_mock_response(response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      response
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Storage.new(mock_connection)
  end

  # Creates a repository with a mock that returns wrapped response
  def create_repo_with_wrapped_response(response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      response
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Storage.new(mock_connection)
  end
end

# =============================================================================
# Repositories::Storage#list_for_node Tests
# NEW TESTS FOR STORAGE-NODE-REFACTOR
# =============================================================================

class RepositoriesStorageListForNodeTest < Minitest::Test
  # Tests for the new list_for_node method that uses /nodes/{node}/storage endpoint

  def setup
    # Mock response from /nodes/{node}/storage API (different format than /cluster/resources)
    @mock_node_storage_response = [
      {
        storage: "local",
        type: "dir",
        total: 107_374_182_400,
        used: 48_318_382_080,
        avail: 59_055_800_320,
        enabled: 1,
        active: 1,
        content: "images,rootdir,vztmpl,iso,backup"
      },
      {
        storage: "local-lvm",
        type: "lvmthin",
        total: 536_870_912_000,
        used: 251_274_936_320,
        avail: 285_595_975_680,
        enabled: 1,
        active: 1,
        content: "images,rootdir"
      },
      {
        storage: "ceph-pool",
        type: "rbd",
        total: 2_199_023_255_552,
        used: 955_630_223_360,
        avail: 1_243_393_032_192,
        enabled: 1,
        active: 1,
        content: "images"
      }
    ]

    @mock_disabled_storage_response = [
      {
        storage: "local",
        type: "dir",
        total: 107_374_182_400,
        used: 48_318_382_080,
        avail: 59_055_800_320,
        enabled: 1,
        active: 1,
        content: "images"
      },
      {
        storage: "backup-disabled",
        type: "nfs",
        total: 0,
        used: 0,
        avail: 0,
        enabled: 0,
        active: 0,
        content: "backup"
      }
    ]
  end

  # ---------------------------
  # list_for_node() Method - Basic
  # ---------------------------

  def test_list_for_node_returns_array_of_storage_models
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage_pools = repo.list_for_node("pve-node1")

    assert_kind_of Array, storage_pools
    assert storage_pools.all? { |s| s.is_a?(Pvectl::Models::Storage) }
  end

  def test_list_for_node_returns_correct_number_of_storage_pools
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage_pools = repo.list_for_node("pve-node1")

    assert_equal 3, storage_pools.length
  end

  def test_list_for_node_returns_empty_array_when_api_returns_empty
    repo = create_repo_for_node("pve-node1", [])

    storage_pools = repo.list_for_node("pve-node1")

    assert_empty storage_pools
  end

  # ---------------------------
  # list_for_node() Method - Field Mapping
  # ---------------------------

  def test_list_for_node_maps_storage_name_correctly
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal "local", storage.name
  end

  def test_list_for_node_maps_type_to_plugintype
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal "dir", storage.plugintype
  end

  def test_list_for_node_maps_used_to_disk
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal 48_318_382_080, storage.disk
    assert_equal 48_318_382_080, storage.used
  end

  def test_list_for_node_maps_total_to_maxdisk
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal 107_374_182_400, storage.maxdisk
    assert_equal 107_374_182_400, storage.total
  end

  def test_list_for_node_includes_avail_attribute
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal 59_055_800_320, storage.avail
  end

  def test_list_for_node_includes_enabled_attribute
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal 1, storage.enabled
    assert storage.enabled?
  end

  def test_list_for_node_includes_active_attribute
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal 1, storage.active_flag
  end

  def test_list_for_node_includes_content_attribute
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal "images,rootdir,vztmpl,iso,backup", storage.content
  end

  def test_list_for_node_sets_node_name_from_parameter
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").first

    assert_equal "pve-node1", storage.node
  end

  def test_list_for_node_sets_shared_to_zero
    # /nodes/{node}/storage doesn't return shared flag, default to 0
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").first

    assert_equal 0, storage.shared
    refute storage.shared?
  end

  # ---------------------------
  # list_for_node() Method - Status Derivation
  # ---------------------------

  def test_list_for_node_derives_status_available_from_active_flag
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }

    assert_equal "available", storage.status
    assert storage.active?
  end

  def test_list_for_node_derives_status_unavailable_when_active_is_zero
    repo = create_repo_for_node("pve-node1", @mock_disabled_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "backup-disabled" }

    assert_equal "unavailable", storage.status
    refute storage.active?
  end

  # ---------------------------
  # list_for_node() Method - Disabled Storage
  # ---------------------------

  def test_list_for_node_includes_disabled_storage
    repo = create_repo_for_node("pve-node1", @mock_disabled_storage_response)

    storage_pools = repo.list_for_node("pve-node1")
    disabled = storage_pools.find { |s| s.name == "backup-disabled" }

    refute_nil disabled
    assert_equal 0, disabled.enabled
    refute disabled.enabled?
  end

  # ---------------------------
  # list_for_node() Method - Presenter Display Methods Work
  # ---------------------------

  def test_list_for_node_storage_works_with_presenter
    repo = create_repo_for_node("pve-node1", @mock_node_storage_response)

    storage = repo.list_for_node("pve-node1").find { |s| s.name == "local" }
    presenter = Pvectl::Presenters::Storage.new
    presenter.to_row(storage)

    assert_equal "dir", presenter.type_display
    assert_equal "100 GB", presenter.total_display
    assert_equal "45 GB", presenter.used_display
    assert_equal "55 GB", presenter.avail_display
    assert_equal "45%", presenter.usage_display
  end

  # ---------------------------
  # list_for_node() Method - Error Handling
  # ---------------------------

  def test_list_for_node_raises_on_api_error
    repo = create_repo_with_error("pve-node1", StandardError.new("Node offline"))

    assert_raises(StandardError) do
      repo.list_for_node("pve-node1")
    end
  end

  private

  # Creates a repository with mock for /nodes/{node}/storage endpoint
  def create_repo_for_node(node_name, response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      response
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      # Validate that correct path is called
      expected_path = "nodes/#{node_name}/storage"
      raise "Unexpected API path: #{path}" unless path == expected_path

      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Storage.new(mock_connection)
  end

  # Creates a repository that raises an error
  def create_repo_with_error(node_name, error)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) do |**_kwargs|
      raise error
    end

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |_path|
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) do
      mock_client
    end

    Pvectl::Repositories::Storage.new(mock_connection)
  end
end

# =============================================================================
# Repositories::Storage#describe Tests
# =============================================================================

class RepositoriesStorageDescribeTest < Minitest::Test
  # Tests for the describe method that fetches comprehensive storage details

  def setup
    # Mock response from /cluster/resources?type=storage
    @mock_cluster_resources_response = [
      {
        storage: "local",
        node: "pve-node1",
        type: "storage",
        plugintype: "dir",
        status: "available",
        disk: 48_318_382_080,
        maxdisk: 107_374_182_400,
        content: "images,rootdir,vztmpl,iso,backup",
        shared: 0
      },
      {
        storage: "nfs-backup",
        node: "pve-node1",
        type: "storage",
        plugintype: "nfs",
        status: "available",
        disk: 1_288_490_188_800,
        maxdisk: 4_398_046_511_104,
        content: "backup,iso",
        shared: 1
      }
    ]

    # Mock response from /storage/{name} (configuration)
    @mock_storage_config_local = {
      storage: "local",
      type: "dir",
      path: "/var/lib/vz",
      content: "images,rootdir,vztmpl,iso,backup",
      nodes: nil,
      maxfiles: 3
    }

    @mock_storage_config_nfs = {
      storage: "nfs-backup",
      type: "nfs",
      server: "192.168.1.100",
      export: "/exports/backup",
      path: "/mnt/pve/nfs-backup",
      content: "backup,iso",
      nodes: "pve-node1,pve-node2",
      "prune-backups": { "keep-last": 3, "keep-daily": 7 }
    }

    # Mock response from /nodes/{node}/storage/{name}/status
    @mock_storage_status = {
      avail: 59_055_800_320,
      used: 48_318_382_080,
      total: 107_374_182_400,
      enabled: 1,
      active: 1,
      content: "images,rootdir,vztmpl,iso,backup",
      type: "dir"
    }

    # Mock response from /nodes/{node}/storage/{name}/content
    @mock_storage_content = [
      {
        volid: "local:iso/ubuntu-22.04.iso",
        format: "iso",
        size: 3_826_831_360,
        ctime: 1_698_000_000
      },
      {
        volid: "local:backup/vzdump-qemu-100-2024.vma.zst",
        format: "vma.zst",
        size: 2_147_483_648,
        ctime: 1_698_100_000
      }
    ]

    # Mock response from /nodes (for finding online node)
    @mock_nodes_response = [
      { node: "pve-node1", status: "online" },
      { node: "pve-node2", status: "online" }
    ]
  end

  # ---------------------------
  # describe() Method - Basic
  # ---------------------------

  def test_describe_returns_storage_model
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_instance_of Pvectl::Models::Storage, storage
  end

  def test_describe_returns_nil_for_nonexistent_storage
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: {},
      storage_status: {},
      storage_content: [],
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nonexistent")

    assert_nil storage
  end

  def test_describe_includes_basic_attributes_from_list
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal "local", storage.name
    assert_equal "dir", storage.plugintype
    assert_equal "available", storage.status
    assert_equal "pve-node1", storage.node
    assert_equal 0, storage.shared
  end

  # ---------------------------
  # describe() Method - Configuration Attributes
  # ---------------------------

  def test_describe_includes_path_from_config
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal "/var/lib/vz", storage.path
  end

  def test_describe_includes_server_from_config_for_nfs
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nfs-backup")

    assert_equal "192.168.1.100", storage.server
  end

  def test_describe_includes_export_from_config_for_nfs
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nfs-backup")

    assert_equal "/exports/backup", storage.export
  end

  def test_describe_includes_nodes_allowed_from_config
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nfs-backup")

    assert_equal "pve-node1,pve-node2", storage.nodes_allowed
  end

  def test_describe_includes_prune_backups_from_config
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nfs-backup")

    refute_nil storage.prune_backups
    assert_equal 3, storage.prune_backups[:"keep-last"]
  end

  def test_describe_includes_maxfiles_from_config
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal 3, storage.max_files
  end

  # ---------------------------
  # describe() Method - Status Attributes
  # ---------------------------

  def test_describe_includes_avail_from_status
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal 59_055_800_320, storage.avail
  end

  def test_describe_includes_enabled_from_status
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal 1, storage.enabled
    assert storage.enabled?
  end

  def test_describe_includes_active_flag_from_status
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal 1, storage.active_flag
  end

  # ---------------------------
  # describe() Method - Content (Volumes)
  # ---------------------------

  def test_describe_includes_volumes_from_content
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_equal 2, storage.volumes.length
    assert_equal "local:iso/ubuntu-22.04.iso", storage.volumes.first[:volid]
  end

  def test_describe_returns_empty_volumes_when_content_api_fails
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: @mock_storage_status,
      storage_content: :raise_error,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_empty storage.volumes
  end

  # ---------------------------
  # describe() Method - Shared Storage
  # ---------------------------

  def test_describe_for_shared_storage_finds_online_node
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("nfs-backup")

    # Should successfully fetch data using any online node
    refute_nil storage
    assert_equal "nfs-backup", storage.name
  end

  # ---------------------------
  # describe() Method - Error Handling
  # ---------------------------

  def test_describe_handles_config_api_error_gracefully
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: :raise_error,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    # Should still return model with basic attributes
    refute_nil storage
    assert_equal "local", storage.name
    assert_nil storage.path
  end

  def test_describe_handles_status_api_error_gracefully
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_local,
      storage_status: :raise_error,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    # Should still return model with basic attributes
    refute_nil storage
    assert_equal "local", storage.name
  end

  def test_describe_handles_nodes_api_error_gracefully
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config_nfs,
      storage_status: :raise_error,
      storage_content: :raise_error,
      nodes: :raise_error
    )

    storage = repo.describe("nfs-backup")

    # Should still return model with basic attributes
    refute_nil storage
    assert_equal "nfs-backup", storage.name
  end

  private

  # Creates a repository with mock for describe endpoints
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def create_describe_repo(cluster_resources:, storage_config:, storage_status:, storage_content:, nodes:)
    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      mock_resource = Object.new

      case path
      when "cluster/resources"
        mock_resource.define_singleton_method(:get) { |**_kwargs| cluster_resources }
      when /^storage\/(.+)$/
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          raise StandardError, "API error" if storage_config == :raise_error

          storage_config
        end
      when /^nodes\/[^\/]+\/storage\/[^\/]+\/status$/
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          raise StandardError, "API error" if storage_status == :raise_error

          storage_status
        end
      when /^nodes\/[^\/]+\/storage\/[^\/]+\/content$/
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          raise StandardError, "API error" if storage_content == :raise_error

          storage_content
        end
      when "nodes"
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          raise StandardError, "API error" if nodes == :raise_error

          nodes
        end
      else
        mock_resource.define_singleton_method(:get) { |**_kwargs| [] }
      end

      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    Pvectl::Repositories::Storage.new(mock_connection)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end

# =============================================================================
# Repositories::Storage#list_instances Tests
# =============================================================================

class RepositoriesStorageListInstancesTest < Minitest::Test
  # Tests for list_instances method that returns all instances of a storage

  def setup
    @mock_api_response = [
      {
        storage: "local",
        node: "pve-node1",
        plugintype: "dir",
        status: "available",
        disk: 48_318_382_080,
        maxdisk: 107_374_182_400,
        content: "images,rootdir",
        shared: 0
      },
      {
        storage: "local",
        node: "pve-node2",
        plugintype: "dir",
        status: "available",
        disk: 52_428_800_000,
        maxdisk: 107_374_182_400,
        content: "images,rootdir",
        shared: 0
      },
      {
        storage: "ceph-pool",
        node: "pve-node1",
        plugintype: "rbd",
        status: "available",
        disk: 955_630_223_360,
        maxdisk: 2_199_023_255_552,
        content: "images",
        shared: 1
      },
      {
        storage: "ceph-pool",
        node: "pve-node2",
        plugintype: "rbd",
        status: "available",
        disk: 955_630_223_360,
        maxdisk: 2_199_023_255_552,
        content: "images",
        shared: 1
      }
    ]
  end

  # ---------------------------
  # list_instances() Method
  # ---------------------------

  def test_list_instances_returns_all_instances_of_local_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    instances = repo.list_instances("local")

    assert_equal 2, instances.length
    assert instances.all? { |s| s.name == "local" }
  end

  def test_list_instances_returns_all_instances_of_shared_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    instances = repo.list_instances("ceph-pool")

    # Shared storage appears once per node in raw API response
    assert_equal 2, instances.length
    assert instances.all? { |s| s.name == "ceph-pool" }
  end

  def test_list_instances_returns_empty_for_nonexistent_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    instances = repo.list_instances("nonexistent")

    assert_empty instances
  end

  def test_list_instances_returns_storage_models
    repo = create_repo_with_mock_response(@mock_api_response)

    instances = repo.list_instances("local")

    assert instances.all? { |s| s.is_a?(Pvectl::Models::Storage) }
  end

  def test_list_instances_includes_node_information
    repo = create_repo_with_mock_response(@mock_api_response)

    instances = repo.list_instances("local")
    nodes = instances.map(&:node).sort

    assert_equal %w[pve-node1 pve-node2], nodes
  end

  # ---------------------------
  # get_for_node() Method
  # ---------------------------

  def test_get_for_node_returns_storage_for_specific_node
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.get_for_node("local", "pve-node1")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "local", storage.name
    assert_equal "pve-node1", storage.node
  end

  def test_get_for_node_returns_nil_for_invalid_node
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.get_for_node("local", "nonexistent-node")

    assert_nil storage
  end

  def test_get_for_node_returns_nil_for_nonexistent_storage
    repo = create_repo_with_mock_response(@mock_api_response)

    storage = repo.get_for_node("nonexistent", "pve-node1")

    assert_nil storage
  end

  private

  def create_repo_with_mock_response(response)
    mock_resource = Object.new
    mock_resource.define_singleton_method(:get) { |**_kwargs| response }

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) { |_path| mock_resource }

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    Pvectl::Repositories::Storage.new(mock_connection)
  end
end

# =============================================================================
# Repositories::Storage#describe with node parameter Tests
# =============================================================================

class RepositoriesStorageDescribeWithNodeTest < Minitest::Test
  # Tests for describe method with node parameter

  def setup
    @mock_cluster_resources_response = [
      {
        storage: "local",
        node: "pve-node1",
        plugintype: "dir",
        status: "available",
        disk: 48_318_382_080,
        maxdisk: 107_374_182_400,
        content: "images,rootdir",
        shared: 0
      },
      {
        storage: "local",
        node: "pve-node2",
        plugintype: "dir",
        status: "available",
        disk: 52_428_800_000,
        maxdisk: 107_374_182_400,
        content: "images,rootdir",
        shared: 0
      }
    ]

    @mock_storage_config = {
      storage: "local",
      type: "dir",
      path: "/var/lib/vz",
      content: "images,rootdir"
    }

    @mock_storage_status = {
      avail: 59_055_800_320,
      used: 48_318_382_080,
      total: 107_374_182_400,
      enabled: 1,
      active: 1
    }

    @mock_storage_content = []
    @mock_nodes_response = [{ node: "pve-node1", status: "online" }]
  end

  def test_describe_with_node_returns_storage_for_specific_node
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local", node: "pve-node1")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "local", storage.name
    assert_equal "pve-node1", storage.node
  end

  def test_describe_with_node_returns_nil_for_invalid_node
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local", node: "nonexistent-node")

    assert_nil storage
  end

  def test_describe_without_node_returns_first_instance
    repo = create_describe_repo(
      cluster_resources: @mock_cluster_resources_response,
      storage_config: @mock_storage_config,
      storage_status: @mock_storage_status,
      storage_content: @mock_storage_content,
      nodes: @mock_nodes_response
    )

    storage = repo.describe("local")

    assert_instance_of Pvectl::Models::Storage, storage
    assert_equal "local", storage.name
  end

  private

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def create_describe_repo(cluster_resources:, storage_config:, storage_status:, storage_content:, nodes:)
    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      mock_resource = Object.new

      case path
      when "cluster/resources"
        mock_resource.define_singleton_method(:get) { |**_kwargs| cluster_resources }
      when /^storage\/(.+)$/
        mock_resource.define_singleton_method(:get) { |**_kwargs| storage_config }
      when /^nodes\/[^\/]+\/storage\/[^\/]+\/status$/
        mock_resource.define_singleton_method(:get) { |**_kwargs| storage_status }
      when /^nodes\/[^\/]+\/storage\/[^\/]+\/content$/
        mock_resource.define_singleton_method(:get) { |**_kwargs| storage_content }
      when "nodes"
        mock_resource.define_singleton_method(:get) { |**_kwargs| nodes }
      else
        mock_resource.define_singleton_method(:get) { |**_kwargs| [] }
      end

      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    Pvectl::Repositories::Storage.new(mock_connection)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
