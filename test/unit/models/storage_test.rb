# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::Storage Tests
# =============================================================================

class ModelsStorageTest < Minitest::Test
  # Tests for the Storage domain model
  # NOTE: Display methods have been moved to Presenters::Storage
  # This file tests only data attributes and predicate methods

  def setup
    @active_storage_attrs = {
      name: "local",
      plugintype: "dir",
      status: "available",
      node: "pve-node1",
      disk: 48_318_382_080,        # ~45 GB
      maxdisk: 107_374_182_400,    # 100 GB
      content: "images,rootdir,vztmpl,iso,backup",
      shared: 0
    }

    @shared_storage_attrs = {
      name: "ceph-pool",
      plugintype: "rbd",
      status: "available",
      node: "pve-node1",
      disk: 955_630_223_360,       # ~890 GB
      maxdisk: 2_199_023_255_552,  # 2 TB
      content: "images",
      shared: 1
    }

    @inactive_storage_attrs = {
      name: "offline-storage",
      plugintype: "dir",
      status: "unavailable",
      node: "pve-node1",
      disk: nil,
      maxdisk: 53_687_091_200,     # 50 GB
      content: "images",
      shared: 0
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_storage_class_exists
    assert_kind_of Class, Pvectl::Models::Storage
  end

  def test_storage_inherits_from_base
    assert Pvectl::Models::Storage < Pvectl::Models::Base
  end

  # ---------------------------
  # Attribute Readers
  # ---------------------------

  def test_name_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal "local", storage.name
  end

  def test_name_attribute_from_storage_key
    # API uses "storage" key instead of "name"
    attrs = { storage: "local-lvm", plugintype: "lvmthin", status: "available" }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "local-lvm", storage.name
  end

  def test_plugintype_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal "dir", storage.plugintype
  end

  def test_plugintype_from_type_key
    # Model can also accept "type" key for backward compatibility
    attrs = { name: "test", type: "lvmthin", status: "available" }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "lvmthin", storage.plugintype
  end

  def test_status_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal "available", storage.status
  end

  def test_node_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal "pve-node1", storage.node
  end

  def test_disk_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal 48_318_382_080, storage.disk
  end

  def test_maxdisk_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal 107_374_182_400, storage.maxdisk
  end

  def test_content_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal "images,rootdir,vztmpl,iso,backup", storage.content
  end

  def test_shared_attribute
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal 0, storage.shared
  end

  def test_shared_defaults_to_zero
    attrs = { name: "test", plugintype: "dir", status: "available" }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 0, storage.shared
  end

  # ---------------------------
  # active? Predicate Method
  # ---------------------------

  def test_active_returns_true_for_available_storage
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert storage.active?
  end

  def test_active_returns_true_for_active_status
    attrs = @active_storage_attrs.merge(status: "active")
    storage = Pvectl::Models::Storage.new(attrs)
    assert storage.active?
  end

  def test_active_returns_false_for_unavailable_storage
    storage = Pvectl::Models::Storage.new(@inactive_storage_attrs)
    refute storage.active?
  end

  # ---------------------------
  # shared? Predicate Method
  # ---------------------------

  def test_shared_returns_true_for_shared_storage
    storage = Pvectl::Models::Storage.new(@shared_storage_attrs)
    assert storage.shared?
  end

  def test_shared_returns_false_for_local_storage
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    refute storage.shared?
  end

  # ---------------------------
  # String Keys in Attributes
  # ---------------------------

  def test_accepts_string_keys
    string_attrs = {
      "storage" => "test-storage",
      "plugintype" => "nfs",
      "status" => "available",
      "node" => "pve-node1",
      "shared" => 1
    }
    storage = Pvectl::Models::Storage.new(string_attrs)
    assert_equal "test-storage", storage.name
    assert_equal "nfs", storage.plugintype
    assert storage.shared?
  end

  # ===========================================================================
  # Tests for Storage model with node API support
  # ===========================================================================

  # ---------------------------
  # New Attributes from /nodes/{node}/storage API
  # ---------------------------

  def test_avail_attribute
    attrs = @active_storage_attrs.merge(avail: 59_055_800_320)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 59_055_800_320, storage.avail
  end

  def test_avail_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.avail
  end

  def test_enabled_attribute
    attrs = @active_storage_attrs.merge(enabled: 1)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 1, storage.enabled
  end

  def test_enabled_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.enabled
  end

  def test_active_flag_attribute
    attrs = @active_storage_attrs.merge(active: 1)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 1, storage.active_flag
  end

  def test_active_flag_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.active_flag
  end

  # ---------------------------
  # Getter Aliases (used/total)
  # ---------------------------

  def test_used_alias_returns_disk_value
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal storage.disk, storage.used
    assert_equal 48_318_382_080, storage.used
  end

  def test_total_alias_returns_maxdisk_value
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal storage.maxdisk, storage.total
    assert_equal 107_374_182_400, storage.total
  end

  def test_used_alias_with_node_api_format
    # /nodes/{node}/storage uses 'used' instead of 'disk'
    attrs = { name: "local", type: "dir", used: 53_687_091_200, total: 107_374_182_400 }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 53_687_091_200, storage.used
    assert_equal 53_687_091_200, storage.disk
  end

  def test_total_alias_with_node_api_format
    # /nodes/{node}/storage uses 'total' instead of 'maxdisk'
    attrs = { name: "local", type: "dir", used: 53_687_091_200, total: 107_374_182_400 }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 107_374_182_400, storage.total
    assert_equal 107_374_182_400, storage.maxdisk
  end

  # ---------------------------
  # enabled? Predicate Method
  # ---------------------------

  def test_enabled_returns_true_when_enabled_is_1
    attrs = @active_storage_attrs.merge(enabled: 1)
    storage = Pvectl::Models::Storage.new(attrs)
    assert storage.enabled?
  end

  def test_enabled_returns_false_when_enabled_is_0
    attrs = @active_storage_attrs.merge(enabled: 0)
    storage = Pvectl::Models::Storage.new(attrs)
    refute storage.enabled?
  end

  def test_enabled_returns_false_when_enabled_is_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    refute storage.enabled?
  end

  # ---------------------------
  # Initialization from Node API Format
  # ---------------------------

  def test_initialization_from_node_api_format
    # Simulates data from /nodes/{node}/storage endpoint
    node_api_attrs = {
      storage: "local",
      type: "dir",
      total: 107_374_182_400,
      used: 48_318_382_080,
      avail: 59_055_800_320,
      enabled: 1,
      active: 1,
      content: "images,rootdir,vztmpl,iso,backup"
    }
    storage = Pvectl::Models::Storage.new(node_api_attrs)

    assert_equal "local", storage.name
    assert_equal "dir", storage.plugintype
    assert_equal 107_374_182_400, storage.maxdisk
    assert_equal 48_318_382_080, storage.disk
    assert_equal 59_055_800_320, storage.avail
    assert_equal 1, storage.enabled
    assert_equal 1, storage.active_flag
    assert_equal "images,rootdir,vztmpl,iso,backup", storage.content
  end

  def test_status_derived_from_active_flag_when_status_missing
    # /nodes/{node}/storage doesn't return status, derive from active flag
    attrs = { name: "local", type: "dir", active: 1 }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "available", storage.status
    assert storage.active?
  end

  def test_status_derived_as_unavailable_when_active_is_0
    attrs = { name: "local", type: "dir", active: 0 }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "unavailable", storage.status
    refute storage.active?
  end

  def test_explicit_status_takes_precedence_over_active_flag
    attrs = { name: "local", type: "dir", status: "available", active: 0 }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "available", storage.status
  end

  # ===========================================================================
  # Tests for extended Storage model attributes (describe command)
  # ===========================================================================

  # ---------------------------
  # Configuration Fields from /storage/{storage} API
  # ---------------------------

  def test_path_attribute
    attrs = @active_storage_attrs.merge(path: "/var/lib/vz")
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "/var/lib/vz", storage.path
  end

  def test_path_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.path
  end

  def test_server_attribute
    attrs = @shared_storage_attrs.merge(server: "192.168.1.100")
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "192.168.1.100", storage.server
  end

  def test_server_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.server
  end

  def test_export_attribute
    attrs = @shared_storage_attrs.merge(export: "/exports/vm-data")
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "/exports/vm-data", storage.export
  end

  def test_export_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.export
  end

  def test_pool_attribute
    attrs = @shared_storage_attrs.merge(pool: "rbd-pool")
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "rbd-pool", storage.pool
  end

  def test_pool_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.pool
  end

  def test_vgname_attribute
    attrs = { name: "local-lvm", plugintype: "lvm", status: "available", vgname: "pve" }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "pve", storage.vgname
  end

  def test_vgname_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.vgname
  end

  def test_thinpool_attribute
    attrs = { name: "local-lvm", plugintype: "lvmthin", status: "available", thinpool: "data" }
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "data", storage.thinpool
  end

  def test_thinpool_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.thinpool
  end

  def test_nodes_allowed_attribute
    # API returns "nodes" but we expose as "nodes_allowed"
    attrs = @active_storage_attrs.merge(nodes: "pve1,pve2,pve3")
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal "pve1,pve2,pve3", storage.nodes_allowed
  end

  def test_nodes_allowed_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.nodes_allowed
  end

  def test_prune_backups_attribute
    # API uses hyphen: "prune-backups"
    prune_policy = { "keep-daily" => 7, "keep-weekly" => 4, "keep-monthly" => 6 }
    attrs = @active_storage_attrs.merge("prune-backups": prune_policy)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal prune_policy, storage.prune_backups
  end

  def test_prune_backups_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.prune_backups
  end

  def test_max_files_attribute
    # API uses "maxfiles"
    attrs = @active_storage_attrs.merge(maxfiles: 5)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal 5, storage.max_files
  end

  def test_max_files_defaults_to_nil
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_nil storage.max_files
  end

  # ---------------------------
  # Volumes (Content Summary)
  # ---------------------------

  def test_volumes_attribute
    volumes_data = [
      { volid: "local:iso/ubuntu-22.04.iso", format: "iso", size: 1_234_567_890 },
      { volid: "local:backup/vzdump-qemu-100.tar.zst", format: "tar.zst", size: 9_876_543_210 }
    ]
    attrs = @active_storage_attrs.merge(volumes: volumes_data)
    storage = Pvectl::Models::Storage.new(attrs)
    assert_equal volumes_data, storage.volumes
    assert_equal 2, storage.volumes.size
  end

  def test_volumes_defaults_to_empty_array
    storage = Pvectl::Models::Storage.new(@active_storage_attrs)
    assert_equal [], storage.volumes
    assert_kind_of Array, storage.volumes
  end

  # ---------------------------
  # Full Configuration Example (NFS Storage)
  # ---------------------------

  def test_nfs_storage_with_all_config_fields
    nfs_attrs = {
      name: "nfs-backup",
      plugintype: "nfs",
      status: "available",
      shared: 1,
      server: "192.168.1.50",
      export: "/exports/backups",
      path: "/mnt/pve/nfs-backup",
      content: "backup,iso,vztmpl",
      nodes: "pve1,pve2",
      "prune-backups": { "keep-daily" => 7, "keep-weekly" => 4 },
      maxfiles: 10
    }
    storage = Pvectl::Models::Storage.new(nfs_attrs)

    assert_equal "nfs-backup", storage.name
    assert_equal "nfs", storage.plugintype
    assert storage.shared?
    assert_equal "192.168.1.50", storage.server
    assert_equal "/exports/backups", storage.export
    assert_equal "/mnt/pve/nfs-backup", storage.path
    assert_equal "backup,iso,vztmpl", storage.content
    assert_equal "pve1,pve2", storage.nodes_allowed
    assert_equal({ "keep-daily" => 7, "keep-weekly" => 4 }, storage.prune_backups)
    assert_equal 10, storage.max_files
    assert_equal [], storage.volumes
  end

  # ---------------------------
  # Full Configuration Example (LVMThin Storage)
  # ---------------------------

  def test_lvmthin_storage_with_all_config_fields
    lvmthin_attrs = {
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      shared: 0,
      vgname: "pve",
      thinpool: "data",
      content: "images,rootdir"
    }
    storage = Pvectl::Models::Storage.new(lvmthin_attrs)

    assert_equal "local-lvm", storage.name
    assert_equal "lvmthin", storage.plugintype
    refute storage.shared?
    assert_equal "pve", storage.vgname
    assert_equal "data", storage.thinpool
    assert_equal "images,rootdir", storage.content
    assert_nil storage.server
    assert_nil storage.export
    assert_nil storage.path
  end

  # ---------------------------
  # Full Configuration Example (Ceph/RBD Storage)
  # ---------------------------

  def test_ceph_storage_with_all_config_fields
    ceph_attrs = {
      name: "ceph-pool",
      plugintype: "rbd",
      status: "available",
      shared: 1,
      pool: "rbd-pool",
      server: "10.0.0.1,10.0.0.2,10.0.0.3",
      content: "images"
    }
    storage = Pvectl::Models::Storage.new(ceph_attrs)

    assert_equal "ceph-pool", storage.name
    assert_equal "rbd", storage.plugintype
    assert storage.shared?
    assert_equal "rbd-pool", storage.pool
    assert_equal "10.0.0.1,10.0.0.2,10.0.0.3", storage.server
    assert_equal "images", storage.content
    assert_nil storage.vgname
    assert_nil storage.thinpool
    assert_nil storage.path
  end

  # ---------------------------
  # String Keys Support for New Attributes
  # ---------------------------

  def test_new_attributes_accept_string_keys
    string_attrs = {
      "name" => "nfs-test",
      "plugintype" => "nfs",
      "status" => "available",
      "server" => "192.168.1.100",
      "export" => "/exports/test",
      "path" => "/mnt/pve/nfs-test",
      "nodes" => "pve1,pve2",
      "prune-backups" => { "keep-daily" => 7 },
      "maxfiles" => 5,
      "volumes" => [{ "volid" => "test:iso/test.iso" }]
    }
    storage = Pvectl::Models::Storage.new(string_attrs)

    assert_equal "nfs-test", storage.name
    assert_equal "192.168.1.100", storage.server
    assert_equal "/exports/test", storage.export
    assert_equal "/mnt/pve/nfs-test", storage.path
    assert_equal "pve1,pve2", storage.nodes_allowed
    assert_equal({ "keep-daily" => 7 }, storage.prune_backups)
    assert_equal 5, storage.max_files
    assert_equal [{ "volid" => "test:iso/test.iso" }], storage.volumes
  end
end
