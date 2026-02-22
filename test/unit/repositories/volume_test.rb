# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Volume Tests
# =============================================================================

class RepositoriesVolumeTest < Minitest::Test
  def setup
    @vm_configs = {
      100 => {
        node: "pve1",
        config: {
          scsi0: "local-lvm:vm-100-disk-0,size=32G,discard=on,ssd=1",
          scsi1: "local-lvm:vm-100-disk-1,size=64G,cache=writeback",
          net0: "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0",
          boot: "order=scsi0",
          cores: 4
        }
      },
      101 => {
        node: "pve2",
        config: {
          scsi0: "local-lvm:vm-101-disk-0,size=50G",
          ide2: "local:iso/ubuntu.iso,media=cdrom",
          net0: "virtio=11:22:33:44:55:66,bridge=vmbr0"
        }
      }
    }

    @ct_configs = {
      200 => {
        node: "pve1",
        config: {
          rootfs: "local-lvm:subvol-200-disk-0,size=8G",
          mp0: "local-lvm:subvol-200-disk-1,size=32G,mp=/mnt/data",
          net0: "name=eth0,bridge=vmbr0",
          hostname: "web-ct"
        }
      }
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Repositories::Volume
  end

  def test_inherits_from_base
    assert Pvectl::Repositories::Volume < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list_from_config() - VM
  # ---------------------------

  def test_list_from_config_vm_returns_volumes
    repo = create_volume_repo(vm_configs: @vm_configs)

    volumes = repo.list_from_config(resource_type: "vm", ids: [100])

    assert_equal 2, volumes.size
    assert volumes.all? { |v| v.is_a?(Pvectl::Models::Volume) }

    scsi0 = volumes.find { |v| v.name == "scsi0" }
    assert_equal "local-lvm", scsi0.storage
    assert_equal "vm-100-disk-0", scsi0.volume_id
    assert_equal "32G", scsi0.size
    assert_equal "on", scsi0.discard
    assert_equal 1, scsi0.ssd
    assert_equal "vm", scsi0.resource_type
    assert_equal 100, scsi0.resource_id
    assert_equal "pve1", scsi0.node

    scsi1 = volumes.find { |v| v.name == "scsi1" }
    assert_equal "local-lvm", scsi1.storage
    assert_equal "vm-100-disk-1", scsi1.volume_id
    assert_equal "64G", scsi1.size
    assert_equal "writeback", scsi1.cache
  end

  def test_list_from_config_excludes_cdrom
    repo = create_volume_repo(vm_configs: @vm_configs)

    volumes = repo.list_from_config(resource_type: "vm", ids: [101])

    assert_equal 1, volumes.size
    assert_equal "scsi0", volumes.first.name
    refute volumes.any? { |v| v.name == "ide2" }
  end

  # ---------------------------
  # list_from_config() - CT
  # ---------------------------

  def test_list_from_config_ct_returns_volumes
    repo = create_volume_repo(ct_configs: @ct_configs)

    volumes = repo.list_from_config(resource_type: "ct", ids: [200])

    assert_equal 2, volumes.size
    assert volumes.all? { |v| v.is_a?(Pvectl::Models::Volume) }

    rootfs = volumes.find { |v| v.name == "rootfs" }
    assert_equal "local-lvm", rootfs.storage
    assert_equal "subvol-200-disk-0", rootfs.volume_id
    assert_equal "8G", rootfs.size
    assert_equal "ct", rootfs.resource_type
    assert_equal 200, rootfs.resource_id
    assert_equal "pve1", rootfs.node

    mp0 = volumes.find { |v| v.name == "mp0" }
    assert_equal "/mnt/data", mp0.mp
    assert_equal "32G", mp0.size
  end

  # ---------------------------
  # list_from_config() - Node Filter
  # ---------------------------

  def test_list_from_config_filters_by_node
    repo = create_volume_repo(vm_configs: @vm_configs)

    volumes = repo.list_from_config(resource_type: "vm", ids: [100, 101], node: "pve1")

    # VM 100 is on pve1, VM 101 is on pve2 — only VM 100 volumes returned
    assert volumes.all? { |v| v.node == "pve1" }
    assert_equal 2, volumes.size
    assert volumes.all? { |v| v.resource_id == 100 }
  end

  # ---------------------------
  # find() Method
  # ---------------------------

  def test_find_returns_volume_by_disk_name
    repo = create_volume_repo(vm_configs: @vm_configs)

    volume = repo.find(resource_type: "vm", id: 100, disk_name: "scsi0")

    assert_instance_of Pvectl::Models::Volume, volume
    assert_equal "scsi0", volume.name
    assert_equal "local-lvm", volume.storage
    assert_equal "vm-100-disk-0", volume.volume_id
    assert_equal "32G", volume.size
  end

  def test_find_returns_nil_when_not_found
    repo = create_volume_repo(vm_configs: @vm_configs)

    volume = repo.find(resource_type: "vm", id: 100, disk_name: "nonexistent")

    assert_nil volume
  end

  private

  # Creates a VolumeRepository with mock VM and CT repos
  def create_volume_repo(vm_configs: {}, ct_configs: {})
    mock_vm_repo = MockVmRepo.new(vm_configs)
    mock_ct_repo = MockContainerRepo.new(ct_configs)
    mock_connection = MockVolumeConnection.new

    Pvectl::Repositories::Volume.new(
      mock_connection,
      vm_repo: mock_vm_repo,
      container_repo: mock_ct_repo
    )
  end

  # Mock VM repository that returns configurable data via get() and fetch_config()
  class MockVmRepo
    def initialize(configs)
      @configs = configs
    end

    def get(vmid)
      vmid = vmid.to_i
      data = @configs[vmid]
      return nil unless data

      Pvectl::Models::Vm.new(vmid: vmid, name: "vm-#{vmid}", node: data[:node], status: "running", type: "qemu")
    end

    def fetch_config(node, vmid)
      data = @configs[vmid.to_i]
      return {} unless data && data[:node] == node

      data[:config]
    end
  end

  # Mock Container repository that returns configurable data via get() and fetch_config()
  class MockContainerRepo
    def initialize(configs)
      @configs = configs
    end

    def get(ctid)
      ctid = ctid.to_i
      data = @configs[ctid]
      return nil unless data

      Pvectl::Models::Container.new(vmid: ctid, name: "ct-#{ctid}", node: data[:node], status: "running", type: "lxc")
    end

    def fetch_config(node, ctid)
      data = @configs[ctid.to_i]
      return {} unless data && data[:node] == node

      data[:config]
    end
  end

  # Minimal mock connection for VolumeRepository (needed by Base)
  class MockVolumeConnection
    def client
      @client ||= MockVolumeClient.new
    end
  end

  class MockVolumeClient
    def [](path)
      MockVolumeEndpoint.new(path)
    end
  end

  class MockVolumeEndpoint
    def initialize(path)
      @path = path
    end

    def get(**_kwargs)
      case @path
      when "nodes"
        [{ node: "pve1", status: "online" }, { node: "pve2", status: "online" }]
      else
        []
      end
    end
  end
end
