# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Volume Tests
# =============================================================================

class GetHandlersVolumeTest < Minitest::Test
  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Volume
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: nil)
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
    assert_respond_to handler, :selector_class
  end

  # ---------------------------
  # list() — config mode
  # ---------------------------

  def test_list_delegates_to_list_from_config
    repo = MockVolumeRepo.new(
      config_volumes: [
        Pvectl::Models::Volume.new(
          name: "scsi0", resource_type: "vm", resource_id: 100, node: "pve1"
        )
      ]
    )

    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: repo)
    result = handler.list(args: ["vm", "100"], node: nil)

    assert_equal 1, result.length
    assert_equal "scsi0", result[0].name
    assert_equal "vm", result[0].resource_type
  end

  def test_list_handles_multiple_ids
    repo = MockVolumeRepo.new(
      config_volumes_proc: ->(ids:, **_) { ids.map { |id| Pvectl::Models::Volume.new(name: "scsi0", resource_id: id, node: "pve1") } }
    )

    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: repo)
    result = handler.list(args: ["vm", "100", "101"], node: nil)

    assert_equal 2, result.length
  end

  # ---------------------------
  # list() — storage mode
  # ---------------------------

  def test_list_delegates_to_list_from_storage
    repo = MockVolumeRepo.new(
      storage_volumes: [
        Pvectl::Models::Volume.new(
          storage: "local-lvm", volid: "local-lvm:vm-100-disk-0", node: "pve1"
        )
      ]
    )

    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: repo)
    result = handler.list(args: [], storage: "local-lvm", node: nil)

    assert_equal 1, result.length
    assert_equal "local-lvm", result[0].storage
  end

  # ---------------------------
  # list() — error handling
  # ---------------------------

  def test_list_returns_empty_when_no_resource_type_or_storage
    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: MockVolumeRepo.new)
    result = handler.list(args: [], node: nil)

    assert_empty result
  end

  def test_list_returns_empty_when_only_resource_type_without_id
    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: MockVolumeRepo.new)
    result = handler.list(args: ["vm"], node: nil)

    assert_empty result
  end

  # ---------------------------
  # describe() Method
  # ---------------------------

  def test_describe_delegates_to_find
    repo = MockVolumeRepo.new(
      find_volume: Pvectl::Models::Volume.new(
        name: "scsi0", resource_type: "vm", resource_id: 100, node: "pve1"
      )
    )

    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: repo)
    result = handler.describe(name: "vm", args: ["100", "scsi0"], node: nil)

    assert_equal "scsi0", result.name
    assert_equal "vm", result.resource_type
  end

  def test_describe_raises_when_not_found
    repo = MockVolumeRepo.new(find_volume: nil)

    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: repo)

    assert_raises(Pvectl::ResourceNotFoundError) do
      handler.describe(name: "vm", args: ["100", "scsi0"], node: nil)
    end
  end

  # ---------------------------
  # presenter() Method
  # ---------------------------

  def test_presenter_returns_volume_presenter
    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: nil)

    assert_instance_of Pvectl::Presenters::Volume, handler.presenter
  end

  # ---------------------------
  # selector_class() Method
  # ---------------------------

  def test_selector_class_returns_volume_selector
    handler = Pvectl::Commands::Get::Handlers::Volume.new(repository: nil)

    assert_equal Pvectl::Selectors::Volume, handler.selector_class
  end

  # ---------------------------
  # Registry Integration
  # ---------------------------

  def test_handler_is_registered_for_volumes
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "volumes", Pvectl::Commands::Get::Handlers::Volume, aliases: ["volume", "vol"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("volumes")
  end

  def test_handler_is_registered_with_volume_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "volumes", Pvectl::Commands::Get::Handlers::Volume, aliases: ["volume", "vol"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("volume")
  end

  def test_handler_is_registered_with_vol_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "volumes", Pvectl::Commands::Get::Handlers::Volume, aliases: ["volume", "vol"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("vol")
  end

  def test_registry_returns_volume_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "volumes", Pvectl::Commands::Get::Handlers::Volume, aliases: ["volume", "vol"]
    )

    handler = Pvectl::Commands::Get::ResourceRegistry.for("volumes")

    assert_instance_of Pvectl::Commands::Get::Handlers::Volume, handler
  end

  private

  # Simple mock repository for Volume handler tests
  class MockVolumeRepo
    def initialize(config_volumes: [], storage_volumes: [], find_volume: nil, config_volumes_proc: nil)
      @config_volumes = config_volumes
      @storage_volumes = storage_volumes
      @find_volume = find_volume
      @config_volumes_proc = config_volumes_proc
    end

    def list_from_config(resource_type:, ids:, node: nil)
      if @config_volumes_proc
        @config_volumes_proc.call(resource_type: resource_type, ids: ids, node: node)
      else
        @config_volumes
      end
    end

    def list_from_storage(storage:, node: nil)
      @storage_volumes
    end

    def find(resource_type:, id:, disk_name:, node: nil)
      @find_volume
    end
  end
end
