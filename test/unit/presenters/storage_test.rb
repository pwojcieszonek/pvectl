# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Storage Tests
# =============================================================================

class PresentersStorageTest < Minitest::Test
  # Tests for the Storage presenter
  # Includes display method tests moved from Models::Storage

  def setup
    @active_storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      node: "pve-node1",
      disk: 48_318_382_080,        # ~45 GB
      maxdisk: 107_374_182_400,    # 100 GB
      content: "images,rootdir,vztmpl,iso,backup",
      shared: 0
    )

    @shared_storage = Pvectl::Models::Storage.new(
      name: "ceph-pool",
      plugintype: "rbd",
      status: "available",
      node: "pve-node1",
      disk: 955_630_223_360,       # ~890 GB
      maxdisk: 2_199_023_255_552,  # 2 TB
      content: "images",
      shared: 1
    )

    @inactive_storage = Pvectl::Models::Storage.new(
      name: "offline-storage",
      plugintype: "dir",
      status: "unavailable",
      node: "pve-node1",
      disk: nil,
      maxdisk: 53_687_091_200,     # 50 GB
      content: "images",
      shared: 0
    )

    @large_storage = Pvectl::Models::Storage.new(
      name: "nfs-backup",
      plugintype: "nfs",
      status: "available",
      node: nil,
      disk: 1_288_490_188_800,     # ~1.2 TB
      maxdisk: 4_398_046_511_104,  # 4 TB
      content: "backup,iso",
      shared: 1
    )

    @presenter = Pvectl::Presenters::Storage.new
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_storage_presenter_class_exists
    assert_kind_of Class, Pvectl::Presenters::Storage
  end

  def test_storage_presenter_inherits_from_base
    assert Pvectl::Presenters::Storage < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns() Method
  # ---------------------------

  def test_columns_returns_expected_headers
    expected = %w[NAME TYPE STATUS USED TOTAL %USED NODE]
    assert_equal expected, @presenter.columns
  end

  # ---------------------------
  # extra_columns() Method
  # ---------------------------

  def test_extra_columns_returns_wide_headers
    expected = %w[CONTENT SHARED]
    assert_equal expected, @presenter.extra_columns
  end

  # ---------------------------
  # wide_columns() Method
  # ---------------------------

  def test_wide_columns_combines_columns_and_extra_columns
    expected = %w[NAME TYPE STATUS USED TOTAL %USED NODE CONTENT SHARED]
    assert_equal expected, @presenter.wide_columns
  end

  # ---------------------------
  # to_row() Method - Active Storage
  # ---------------------------

  def test_to_row_for_active_storage
    row = @presenter.to_row(@active_storage)

    assert_equal "local", row[0]       # NAME
    assert_equal "dir", row[1]         # TYPE
    assert_equal "active", row[2]      # STATUS
    assert_equal "45 GB", row[3]       # USED
    assert_equal "100 GB", row[4]      # TOTAL
    assert_equal "45%", row[5]         # %USED
    assert_equal "pve-node1", row[6]   # NODE
  end

  # ---------------------------
  # to_row() Method - Shared Storage
  # ---------------------------

  def test_to_row_for_shared_storage
    row = @presenter.to_row(@shared_storage)

    assert_equal "ceph-pool", row[0]   # NAME
    assert_equal "rbd", row[1]         # TYPE
    assert_equal "active", row[2]      # STATUS
    assert_equal "890 GB", row[3]      # USED
    assert_equal "2.0 TB", row[4]      # TOTAL
    assert_equal "43%", row[5]         # %USED
    assert_equal "-", row[6]           # NODE (shared shows dash)
  end

  # ---------------------------
  # to_row() Method - Inactive Storage
  # ---------------------------

  def test_to_row_for_inactive_storage
    row = @presenter.to_row(@inactive_storage)

    assert_equal "offline-storage", row[0]  # NAME
    assert_equal "dir", row[1]              # TYPE
    assert_equal "inactive", row[2]         # STATUS
    assert_equal "-", row[3]                # USED (inactive shows dash)
    assert_equal "50 GB", row[4]            # TOTAL
    assert_equal "-", row[5]                # %USED (inactive shows dash)
    assert_equal "pve-node1", row[6]        # NODE
  end

  # ---------------------------
  # to_row() Method - Large Storage
  # ---------------------------

  def test_to_row_for_large_storage
    row = @presenter.to_row(@large_storage)

    assert_equal "nfs-backup", row[0]  # NAME
    assert_equal "nfs", row[1]         # TYPE
    assert_equal "active", row[2]      # STATUS
    assert_equal "1.2 TB", row[3]      # USED (TB for large values)
    assert_equal "4.0 TB", row[4]      # TOTAL
    assert_equal "29%", row[5]         # %USED
    assert_equal "-", row[6]           # NODE (shared shows dash)
  end

  # ---------------------------
  # extra_values() Method
  # ---------------------------

  def test_extra_values_for_active_storage
    extra = @presenter.extra_values(@active_storage)

    assert_equal "images,rootdir,vztmpl,iso,backup", extra[0]  # CONTENT
    assert_equal "no", extra[1]                                 # SHARED
  end

  def test_extra_values_for_shared_storage
    extra = @presenter.extra_values(@shared_storage)

    assert_equal "images", extra[0]  # CONTENT
    assert_equal "yes", extra[1]     # SHARED
  end

  # ---------------------------
  # to_wide_row() Method
  # ---------------------------

  def test_to_wide_row_combines_row_and_extra_values
    wide_row = @presenter.to_wide_row(@active_storage)

    assert_equal 9, wide_row.length
    assert_equal "local", wide_row[0]                               # NAME (first standard column)
    assert_equal "images,rootdir,vztmpl,iso,backup", wide_row[7]    # CONTENT (first extra column)
    assert_equal "no", wide_row[8]                                  # SHARED (last column)
  end

  # ---------------------------
  # to_hash() Method
  # ---------------------------

  def test_to_hash_returns_complete_storage_data
    hash = @presenter.to_hash(@active_storage)

    assert_equal "local", hash["name"]
    assert_equal "dir", hash["type"]
    assert_equal "available", hash["status"]
    assert_equal "pve-node1", hash["node"]
  end

  def test_to_hash_includes_shared_as_boolean
    hash = @presenter.to_hash(@active_storage)
    assert_equal false, hash["shared"]

    hash = @presenter.to_hash(@shared_storage)
    assert_equal true, hash["shared"]
  end

  def test_to_hash_includes_content
    hash = @presenter.to_hash(@active_storage)
    assert_equal "images,rootdir,vztmpl,iso,backup", hash["content"]
  end

  def test_to_hash_includes_disk_nested_structure
    hash = @presenter.to_hash(@active_storage)

    assert_kind_of Hash, hash["disk"]
    assert_equal 48_318_382_080, hash["disk"]["used_bytes"]
    assert_equal 107_374_182_400, hash["disk"]["total_bytes"]
    assert_equal 45.0, hash["disk"]["used_gb"]
    assert_equal 100.0, hash["disk"]["total_gb"]
    assert_equal 45, hash["disk"]["usage_percent"]
  end

  def test_to_hash_disk_nil_values_for_inactive_storage
    hash = @presenter.to_hash(@inactive_storage)

    assert_kind_of Hash, hash["disk"]
    assert_nil hash["disk"]["used_bytes"]
    assert_nil hash["disk"]["used_gb"]
    assert_nil hash["disk"]["usage_percent"]
    assert_equal 53_687_091_200, hash["disk"]["total_bytes"]
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_to_row_accepts_context_kwargs
    row = @presenter.to_row(@active_storage, current_context: "prod")
    assert_kind_of Array, row
  end

  def test_extra_values_accepts_context_kwargs
    extra = @presenter.extra_values(@active_storage, highlight: true)
    assert_kind_of Array, extra
  end

  # ===========================================================================
  # Display Methods (moved from Models::Storage)
  # ===========================================================================

  # ---------------------------
  # type_display Method
  # ---------------------------

  def test_type_display_returns_plugintype
    @presenter.to_row(@active_storage)  # Sets up @storage
    assert_equal "dir", @presenter.type_display
  end

  def test_type_display_returns_dash_when_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: nil, status: "available")
    @presenter.to_row(storage)
    assert_equal "-", @presenter.type_display
  end

  # ---------------------------
  # status_display Method
  # ---------------------------

  def test_status_display_returns_active_for_available
    @presenter.to_row(@active_storage)
    assert_equal "active", @presenter.status_display
  end

  def test_status_display_returns_inactive_for_unavailable
    @presenter.to_row(@inactive_storage)
    assert_equal "inactive", @presenter.status_display
  end

  # ---------------------------
  # node_display Method
  # ---------------------------

  def test_node_display_returns_node_for_local_storage
    @presenter.to_row(@active_storage)
    assert_equal "pve-node1", @presenter.node_display
  end

  def test_node_display_returns_dash_for_shared_storage
    @presenter.to_row(@shared_storage)
    assert_equal "-", @presenter.node_display
  end

  def test_node_display_returns_dash_when_node_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", node: nil)
    @presenter.to_row(storage)
    assert_equal "-", @presenter.node_display
  end

  # ---------------------------
  # disk_used_gb Method
  # ---------------------------

  def test_disk_used_gb_for_active_storage
    @presenter.to_row(@active_storage)
    assert_equal 45.0, @presenter.disk_used_gb
  end

  def test_disk_used_gb_returns_nil_when_disk_nil
    @presenter.to_row(@inactive_storage)
    assert_nil @presenter.disk_used_gb
  end

  # ---------------------------
  # disk_total_gb Method
  # ---------------------------

  def test_disk_total_gb_for_storage
    @presenter.to_row(@active_storage)
    assert_equal 100.0, @presenter.disk_total_gb
  end

  def test_disk_total_gb_returns_nil_when_maxdisk_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", maxdisk: nil)
    @presenter.to_row(storage)
    assert_nil @presenter.disk_total_gb
  end

  # ---------------------------
  # usage_percent Method
  # ---------------------------

  def test_usage_percent_for_active_storage
    @presenter.to_row(@active_storage)
    assert_equal 45, @presenter.usage_percent
  end

  def test_usage_percent_returns_nil_when_disk_nil
    @presenter.to_row(@inactive_storage)
    assert_nil @presenter.usage_percent
  end

  def test_usage_percent_returns_nil_when_maxdisk_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", maxdisk: nil)
    @presenter.to_row(storage)
    assert_nil @presenter.usage_percent
  end

  def test_usage_percent_returns_nil_when_maxdisk_zero
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", maxdisk: 0)
    @presenter.to_row(storage)
    assert_nil @presenter.usage_percent
  end

  # ---------------------------
  # used_display Method
  # ---------------------------

  def test_used_display_for_active_storage
    @presenter.to_row(@active_storage)
    assert_equal "45 GB", @presenter.used_display
  end

  def test_used_display_returns_dash_for_inactive_storage
    @presenter.to_row(@inactive_storage)
    assert_equal "-", @presenter.used_display
  end

  def test_used_display_uses_tb_for_large_storage
    @presenter.to_row(@large_storage)
    assert_equal "1.2 TB", @presenter.used_display
  end

  # ---------------------------
  # total_display Method
  # ---------------------------

  def test_total_display_for_storage
    @presenter.to_row(@active_storage)
    assert_equal "100 GB", @presenter.total_display
  end

  def test_total_display_returns_dash_when_maxdisk_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", maxdisk: nil)
    @presenter.to_row(storage)
    assert_equal "-", @presenter.total_display
  end

  def test_total_display_uses_tb_for_large_storage
    @presenter.to_row(@large_storage)
    assert_equal "4.0 TB", @presenter.total_display
  end

  # ---------------------------
  # usage_display Method
  # ---------------------------

  def test_usage_display_for_active_storage
    @presenter.to_row(@active_storage)
    assert_equal "45%", @presenter.usage_display
  end

  def test_usage_display_returns_dash_for_inactive_storage
    @presenter.to_row(@inactive_storage)
    assert_equal "-", @presenter.usage_display
  end

  # ---------------------------
  # content_display Method
  # ---------------------------

  def test_content_display_returns_content
    @presenter.extra_values(@active_storage)
    assert_equal "images,rootdir,vztmpl,iso,backup", @presenter.content_display
  end

  def test_content_display_returns_dash_when_nil
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", content: nil)
    @presenter.extra_values(storage)
    assert_equal "-", @presenter.content_display
  end

  def test_content_display_returns_dash_when_empty
    storage = Pvectl::Models::Storage.new(name: "test", plugintype: "dir", status: "available", content: "")
    @presenter.extra_values(storage)
    assert_equal "-", @presenter.content_display
  end

  # ---------------------------
  # shared_display Method
  # ---------------------------

  def test_shared_display_returns_yes_for_shared
    @presenter.extra_values(@shared_storage)
    assert_equal "yes", @presenter.shared_display
  end

  def test_shared_display_returns_no_for_local
    @presenter.extra_values(@active_storage)
    assert_equal "no", @presenter.shared_display
  end

  # ---------------------------
  # avail_gb Method
  # ---------------------------

  def test_avail_gb_converts_bytes_to_gb
    storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      avail: 59_055_800_320  # ~55 GB
    )
    @presenter.to_row(storage)
    assert_equal 55.0, @presenter.avail_gb
  end

  def test_avail_gb_returns_nil_when_avail_is_nil
    @presenter.to_row(@active_storage)
    assert_nil @presenter.avail_gb
  end

  # ---------------------------
  # avail_display Method
  # ---------------------------

  def test_avail_display_for_active_storage
    storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      avail: 59_055_800_320,
      active: 1
    )
    @presenter.to_row(storage)
    assert_equal "55 GB", @presenter.avail_display
  end

  def test_avail_display_returns_dash_when_not_active
    storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "unavailable",
      avail: 59_055_800_320,
      active: 0
    )
    @presenter.to_row(storage)
    assert_equal "-", @presenter.avail_display
  end

  def test_avail_display_returns_dash_when_avail_nil
    @presenter.to_row(@active_storage)
    assert_equal "-", @presenter.avail_display
  end

  def test_avail_display_uses_tb_for_large_avail
    storage = Pvectl::Models::Storage.new(
      name: "nfs-backup",
      plugintype: "nfs",
      status: "available",
      avail: 3_298_534_883_328,  # ~3 TB
      active: 1
    )
    @presenter.to_row(storage)
    assert_equal "3.0 TB", @presenter.avail_display
  end

  # ===========================================================================
  # to_description() Method
  # ===========================================================================

  # ---------------------------
  # Basic Structure
  # ---------------------------

  def test_to_description_returns_hash
    desc = @presenter.to_description(@active_storage)
    assert_kind_of Hash, desc
  end

  def test_to_description_includes_basic_fields
    desc = @presenter.to_description(@active_storage)

    assert_equal "local", desc["Name"]
    assert_equal "dir", desc["Type"]
    assert_equal "active", desc["Status"]
    assert_equal "no", desc["Shared"]
  end

  def test_to_description_includes_capacity_section
    desc = @presenter.to_description(@active_storage)

    assert_kind_of Hash, desc["Capacity"]
    assert_equal "100 GB", desc["Capacity"]["Total"]
    assert_equal "45 GB", desc["Capacity"]["Used"]
    assert_equal "45%", desc["Capacity"]["Usage"]
  end

  # ---------------------------
  # Nodes Display
  # ---------------------------

  def test_to_description_nodes_shows_all_when_nil
    desc = @presenter.to_description(@active_storage)
    assert_equal "all", desc["Nodes"]
  end

  def test_to_description_nodes_shows_specific_nodes
    storage = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      nodes: "pve1,pve2"
    )
    desc = @presenter.to_description(storage)
    assert_equal "pve1,pve2", desc["Nodes"]
  end

  # ---------------------------
  # Capacity Section
  # ---------------------------

  def test_to_description_capacity_for_inactive_storage
    desc = @presenter.to_description(@inactive_storage)

    assert_equal "50 GB", desc["Capacity"]["Total"]
    assert_equal "-", desc["Capacity"]["Used"]
    assert_equal "-", desc["Capacity"]["Usage"]
  end

  def test_to_description_capacity_for_large_storage
    desc = @presenter.to_description(@large_storage)

    assert_equal "4.0 TB", desc["Capacity"]["Total"]
    assert_equal "1.2 TB", desc["Capacity"]["Used"]
    assert_equal "29%", desc["Capacity"]["Usage"]
  end

  def test_to_description_capacity_includes_available
    storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      disk: 48_318_382_080,
      maxdisk: 107_374_182_400,
      avail: 59_055_800_320  # ~55 GB
    )
    desc = @presenter.to_description(storage)
    assert_equal "55 GB", desc["Capacity"]["Available"]
  end

  # ---------------------------
  # Configuration Section
  # ---------------------------

  def test_to_description_configuration_returns_dash_when_empty
    desc = @presenter.to_description(@active_storage)
    # active_storage has no configuration fields, but has content
    # So it should return a hash with Content Types
    assert_kind_of Hash, desc["Configuration"]
    assert_equal "images,rootdir,vztmpl,iso,backup", desc["Configuration"]["Content Types"]
  end

  def test_to_description_configuration_includes_path
    storage = Pvectl::Models::Storage.new(
      name: "local",
      plugintype: "dir",
      status: "available",
      path: "/var/lib/vz"
    )
    desc = @presenter.to_description(storage)
    assert_equal "/var/lib/vz", desc["Configuration"]["Path"]
  end

  def test_to_description_configuration_includes_nfs_server_and_export
    storage = Pvectl::Models::Storage.new(
      name: "nfs-backup",
      plugintype: "nfs",
      status: "available",
      server: "192.168.1.100",
      export: "/exports/backup"
    )
    desc = @presenter.to_description(storage)
    assert_equal "192.168.1.100", desc["Configuration"]["Server"]
    assert_equal "/exports/backup", desc["Configuration"]["Export"]
  end

  def test_to_description_configuration_includes_lvmthin_fields
    storage = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      vgname: "pve",
      thinpool: "data"
    )
    desc = @presenter.to_description(storage)
    assert_equal "pve", desc["Configuration"]["Volume Group"]
    assert_equal "data", desc["Configuration"]["Thin Pool"]
  end

  def test_to_description_configuration_includes_ceph_pool
    storage = Pvectl::Models::Storage.new(
      name: "ceph-pool",
      plugintype: "rbd",
      status: "available",
      pool: "rbd"
    )
    desc = @presenter.to_description(storage)
    assert_equal "rbd", desc["Configuration"]["Pool"]
  end

  def test_to_description_configuration_returns_dash_when_no_fields
    storage = Pvectl::Models::Storage.new(
      name: "empty",
      plugintype: "unknown",
      status: "available"
    )
    desc = @presenter.to_description(storage)
    assert_equal "-", desc["Configuration"]
  end

  # ---------------------------
  # Content Summary
  # ---------------------------

  def test_to_description_content_summary_returns_dash_when_no_volumes
    desc = @presenter.to_description(@active_storage)
    assert_equal "-", desc["Content Summary"]
  end

  def test_to_description_content_summary_with_volumes
    storage = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      volumes: [
        { content: "images", size: 107_374_182_400 },   # 100 GB
        { content: "images", size: 53_687_091_200 },    # 50 GB
        { content: "rootdir", size: 21_474_836_480 }    # 20 GB
      ]
    )
    desc = @presenter.to_description(storage)

    assert_kind_of Array, desc["Content Summary"]
    assert_equal 2, desc["Content Summary"].length

    # Find images entry
    images_entry = desc["Content Summary"].find { |e| e["TYPE"] == "images" }
    refute_nil images_entry
    assert_equal "2", images_entry["COUNT"]
    assert_equal "150 GB", images_entry["SIZE"]

    # Find rootdir entry
    rootdir_entry = desc["Content Summary"].find { |e| e["TYPE"] == "rootdir" }
    refute_nil rootdir_entry
    assert_equal "1", rootdir_entry["COUNT"]
    assert_equal "20 GB", rootdir_entry["SIZE"]
  end

  def test_to_description_content_summary_with_empty_volumes
    storage = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      volumes: []
    )
    desc = @presenter.to_description(storage)
    assert_equal "-", desc["Content Summary"]
  end

  # ---------------------------
  # Backup Retention
  # ---------------------------

  def test_to_description_backup_retention_returns_dash_when_nil
    desc = @presenter.to_description(@active_storage)
    assert_equal "-", desc["Backup Retention"]
  end

  def test_to_description_backup_retention_with_prune_backups
    storage = Pvectl::Models::Storage.new(
      name: "backup",
      plugintype: "dir",
      status: "available",
      "prune-backups": {
        "keep-last": 3,
        "keep-daily": 7,
        "keep-weekly": 4
      }
    )
    desc = @presenter.to_description(storage)

    assert_kind_of Hash, desc["Backup Retention"]
    assert_equal 3, desc["Backup Retention"]["Keep Last"]
    assert_equal 7, desc["Backup Retention"]["Keep Daily"]
    assert_equal 4, desc["Backup Retention"]["Keep Weekly"]
  end

  def test_to_description_backup_retention_with_symbol_keys
    storage = Pvectl::Models::Storage.new(
      name: "backup",
      plugintype: "dir",
      status: "available",
      "prune-backups": {
        :"keep-last" => 5,
        :"keep-monthly" => 12,
        :"keep-yearly" => 2
      }
    )
    desc = @presenter.to_description(storage)

    assert_kind_of Hash, desc["Backup Retention"]
    assert_equal 5, desc["Backup Retention"]["Keep Last"]
    assert_equal 12, desc["Backup Retention"]["Keep Monthly"]
    assert_equal 2, desc["Backup Retention"]["Keep Yearly"]
  end

  def test_to_description_backup_retention_empty_prune_returns_dash
    storage = Pvectl::Models::Storage.new(
      name: "backup",
      plugintype: "dir",
      status: "available",
      "prune-backups": {}
    )
    desc = @presenter.to_description(storage)
    assert_equal "-", desc["Backup Retention"]
  end

  # ---------------------------
  # Shared Storage
  # ---------------------------

  def test_to_description_for_shared_storage
    desc = @presenter.to_description(@shared_storage)

    assert_equal "ceph-pool", desc["Name"]
    assert_equal "rbd", desc["Type"]
    assert_equal "active", desc["Status"]
    assert_equal "yes", desc["Shared"]
  end

  # ---------------------------
  # Full Example with All Fields
  # ---------------------------

  def test_to_description_full_storage_with_all_fields
    storage = Pvectl::Models::Storage.new(
      name: "local-lvm",
      plugintype: "lvmthin",
      status: "available",
      disk: 251_274_010_624,           # ~234 GB
      maxdisk: 536_870_912_000,        # ~500 GB
      avail: 285_596_901_376,          # ~266 GB
      shared: 0,
      nodes: "pve1,pve2",
      vgname: "pve",
      thinpool: "data",
      content: "images,rootdir",
      "prune-backups": {
        "keep-last": 3,
        "keep-daily": 7,
        "keep-weekly": 4
      },
      volumes: [
        { content: "images", size: 193_273_528_320 },  # ~180 GB
        { content: "rootdir", size: 58_000_482_304 }   # ~54 GB
      ]
    )
    desc = @presenter.to_description(storage)

    # Basic fields
    assert_equal "local-lvm", desc["Name"]
    assert_equal "lvmthin", desc["Type"]
    assert_equal "active", desc["Status"]
    assert_equal "no", desc["Shared"]
    assert_equal "pve1,pve2", desc["Nodes"]

    # Capacity section
    assert_equal "500 GB", desc["Capacity"]["Total"]
    assert_equal "234 GB", desc["Capacity"]["Used"]
    assert_equal "266 GB", desc["Capacity"]["Available"]
    assert_equal "47%", desc["Capacity"]["Usage"]

    # Configuration section
    assert_equal "pve", desc["Configuration"]["Volume Group"]
    assert_equal "data", desc["Configuration"]["Thin Pool"]
    assert_equal "images,rootdir", desc["Configuration"]["Content Types"]

    # Content Summary
    assert_kind_of Array, desc["Content Summary"]
    assert_equal 2, desc["Content Summary"].length

    # Backup Retention
    assert_equal 3, desc["Backup Retention"]["Keep Last"]
    assert_equal 7, desc["Backup Retention"]["Keep Daily"]
    assert_equal 4, desc["Backup Retention"]["Keep Weekly"]
  end
end
