# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Disks Tests
# =============================================================================

class GetHandlersDisksTest < Minitest::Test
  def setup
    @disk1 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sda", model: "Samsung SSD 970", size: 500_107_862_016,
      type: "ssd", health: "PASSED", node: "pve1", used: "LVM"
    )
    @disk2 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/sdb", model: "WD Red 4TB", size: 4_000_787_030_016,
      type: "hdd", health: "PASSED", node: "pve1", used: "ZFS"
    )
    @disk3 = Pvectl::Models::PhysicalDisk.new(
      devpath: "/dev/nvme0n1", model: "Intel P4510", size: 1_000_204_886_016,
      type: "ssd", health: "PASSED", node: "pve2", used: "ext4"
    )
    @all_disks = [@disk1, @disk2, @disk3]
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Disks
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Disks.new(repository: MockDiskRepo.new([]))
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
    assert_respond_to handler, :selector_class
  end

  # ---------------------------
  # list() Method
  # ---------------------------

  def test_list_returns_all_disks
    handler = create_handler(@all_disks)

    disks = handler.list

    assert_equal 3, disks.size
    assert disks.all? { |d| d.is_a?(Pvectl::Models::PhysicalDisk) }
  end

  def test_list_with_node_filter
    handler = create_handler(@all_disks)

    disks = handler.list(node: "pve1")

    assert_equal 2, disks.size
    assert disks.all? { |d| d.node == "pve1" }
  end

  def test_list_with_name_filter_matches_devpath
    handler = create_handler(@all_disks)

    disks = handler.list(name: "/dev/sda")

    assert_equal 1, disks.size
    assert_equal "/dev/sda", disks.first.devpath
  end

  def test_list_returns_empty_when_no_match
    handler = create_handler(@all_disks)

    disks = handler.list(name: "/dev/nonexistent")

    assert_empty disks
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_disk_presenter
    handler = create_handler([])

    presenter = handler.presenter

    assert_instance_of Pvectl::Presenters::Disk, presenter
  end

  # ---------------------------
  # selector_class() Method
  # ---------------------------

  def test_selector_class_returns_disk_selector
    handler = create_handler([])

    assert_equal Pvectl::Selectors::Disk, handler.selector_class
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_disks
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "disks", Pvectl::Commands::Get::Handlers::Disks, aliases: ["disk"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("disks")
  end

  def test_handler_is_registered_with_disk_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "disks", Pvectl::Commands::Get::Handlers::Disks, aliases: ["disk"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("disk")
  end

  def test_registry_returns_disks_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "disks", Pvectl::Commands::Get::Handlers::Disks, aliases: ["disk"]
    )

    handler = Pvectl::Commands::Get::ResourceRegistry.for("disks")

    assert_instance_of Pvectl::Commands::Get::Handlers::Disks, handler
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_returns_disk_with_smart_data
    handler = create_handler(@all_disks)

    disk = handler.describe(name: "/dev/sda")

    assert_instance_of Pvectl::Models::PhysicalDisk, disk
    assert_equal "/dev/sda", disk.devpath
    assert_equal "text", disk.smart_type
  end

  def test_describe_with_node_searches_only_that_node
    handler = create_handler(@all_disks)

    disk = handler.describe(name: "/dev/nvme0n1", node: "pve2")

    assert_equal "pve2", disk.node
    assert_equal "/dev/nvme0n1", disk.devpath
  end

  def test_describe_raises_when_disk_not_found
    handler = create_handler(@all_disks)

    assert_raises(Pvectl::ResourceNotFoundError) do
      handler.describe(name: "/dev/nonexistent")
    end
  end

  def test_describe_finds_disk_across_nodes
    handler = create_handler(@all_disks)

    disk = handler.describe(name: "/dev/nvme0n1")

    assert_equal "pve2", disk.node
  end

  private

  def create_handler(disks)
    Pvectl::Commands::Get::Handlers::Disks.new(repository: MockDiskRepo.new(disks))
  end

  # Simple mock repository
  class MockDiskRepo
    def initialize(disks)
      @disks = disks
    end

    def list(node: nil)
      if node
        @disks.select { |d| d.node == node }
      else
        @disks.dup
      end
    end

    def smart(_node, _disk_path)
      { health: "PASSED", type: "text", text: "Temperature: 34 C", attributes: nil }
    end
  end
end
