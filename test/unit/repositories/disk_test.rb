# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Disk Tests
# =============================================================================

class RepositoriesDiskTest < Minitest::Test
  def setup
    @mock_disks_response = [
      {
        devpath: "/dev/sda",
        model: "Samsung SSD 970 EVO Plus",
        size: 500_107_862_016,
        type: "ssd",
        health: "PASSED",
        serial: "S4EWNX0M123456",
        vendor: "Samsung",
        gpt: 1,
        mounted: 1,
        used: "LVM",
        wwn: "0x5002538e12345678",
        osdid: -1,
        parent: nil
      },
      {
        devpath: "/dev/sdb",
        model: "WDC WD40EFRX-68N32N0",
        size: 4_000_787_030_016,
        type: "hdd",
        health: "PASSED",
        serial: "WD-WCC7K1234567",
        vendor: "Western Digital",
        gpt: 1,
        mounted: 1,
        used: "ZFS",
        wwn: "0x50014ee265432100",
        osdid: -1,
        parent: nil
      }
    ]

    @mock_nodes_response = [
      { node: "pve1", status: "online" },
      { node: "pve2", status: "online" },
      { node: "pve3", status: "offline" }
    ]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Repositories::Disk
  end

  def test_inherits_from_base
    assert Pvectl::Repositories::Disk < Pvectl::Repositories::Base
  end

  # ---------------------------
  # list() - Single Node
  # ---------------------------

  def test_list_returns_physical_disk_models_for_single_node
    repo = create_repo_with_mock(
      disks: { "pve1" => @mock_disks_response },
      nodes: @mock_nodes_response
    )

    disks = repo.list(node: "pve1")

    assert_equal 2, disks.size
    assert disks.all? { |d| d.is_a?(Pvectl::Models::PhysicalDisk) }
  end

  def test_list_sets_node_name_on_models
    repo = create_repo_with_mock(
      disks: { "pve1" => @mock_disks_response },
      nodes: @mock_nodes_response
    )

    disks = repo.list(node: "pve1")

    assert disks.all? { |d| d.node == "pve1" }
  end

  def test_list_maps_api_fields_correctly
    repo = create_repo_with_mock(
      disks: { "pve1" => @mock_disks_response },
      nodes: @mock_nodes_response
    )

    disk = repo.list(node: "pve1").first

    assert_equal "/dev/sda", disk.devpath
    assert_equal "Samsung SSD 970 EVO Plus", disk.model
    assert_equal 500_107_862_016, disk.size
    assert_equal "ssd", disk.type
    assert_equal "PASSED", disk.health
    assert_equal "S4EWNX0M123456", disk.serial
    assert_equal "Samsung", disk.vendor
    assert_equal 1, disk.gpt
    assert_equal 1, disk.mounted
    assert_equal "LVM", disk.used
    assert_equal "0x5002538e12345678", disk.wwn
    assert_equal(-1, disk.osdid)
    assert_nil disk.parent
  end

  # ---------------------------
  # list() - All Nodes
  # ---------------------------

  def test_list_without_node_fetches_all_online_nodes
    repo = create_repo_with_mock(
      disks: {
        "pve1" => @mock_disks_response,
        "pve2" => [{ devpath: "/dev/nvme0n1", model: "Intel P4510", size: 1_000_204_886_016, type: "ssd", health: "PASSED" }]
      },
      nodes: @mock_nodes_response
    )

    disks = repo.list

    # 2 from pve1 + 1 from pve2 (pve3 is offline, skipped)
    assert_equal 3, disks.size
    assert_equal %w[pve1 pve1 pve2], disks.map(&:node)
  end

  def test_list_skips_offline_nodes
    repo = create_repo_with_mock(
      disks: { "pve1" => @mock_disks_response },
      nodes: @mock_nodes_response
    )

    disks = repo.list

    # Only pve1 and pve2 are online; pve2 has no disks configured in mock
    refute disks.any? { |d| d.node == "pve3" }
  end

  # ---------------------------
  # list() - Error Handling
  # ---------------------------

  def test_list_returns_empty_array_when_api_returns_empty
    repo = create_repo_with_mock(
      disks: { "pve1" => [] },
      nodes: @mock_nodes_response
    )

    disks = repo.list(node: "pve1")

    assert_empty disks
  end

  def test_list_handles_api_error_for_node_gracefully
    repo = create_repo_with_mock(
      disks: { "pve1" => StandardError.new("API error") },
      nodes: @mock_nodes_response
    )

    disks = repo.list(node: "pve1")

    assert_empty disks
  end

  private

  def create_repo_with_mock(disks:, nodes:)
    connection = MockDiskConnection.new(disks: disks, nodes: nodes)
    Pvectl::Repositories::Disk.new(connection)
  end

  # Mock connection that simulates Proxmox API responses
  class MockDiskConnection
    def initialize(disks:, nodes:)
      @disks = disks
      @nodes = nodes
    end

    def client
      @client ||= MockClient.new(disks: @disks, nodes: @nodes)
    end
  end

  class MockClient
    def initialize(disks:, nodes:)
      @disks = disks
      @nodes = nodes
    end

    def [](path)
      MockEndpoint.new(path, disks: @disks, nodes: @nodes)
    end
  end

  class MockEndpoint
    def initialize(path, disks:, nodes:)
      @path = path
      @disks = disks
      @nodes = nodes
    end

    def get(**_kwargs)
      case @path
      when "nodes"
        @nodes
      when /\Anodes\/([^\/]+)\/disks\/list\z/
        node_name = Regexp.last_match(1)
        result = @disks[node_name]
        raise result if result.is_a?(StandardError)

        result || []
      else
        []
      end
    end
  end
end
