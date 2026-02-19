# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::ResourceRegistry Tests
# =============================================================================

class GetResourceRegistryTest < Minitest::Test
  # Tests for the resource handler registry

  def setup
    # Reset registry before each test
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    # Clean up after each test
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_registry_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::ResourceRegistry
  end

  # ---------------------------
  # .register() Method
  # ---------------------------

  def test_register_adds_handler_by_string_type
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("nodes")
  end

  def test_register_adds_handler_by_symbol_type
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register(:vms, mock_handler_class)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("vms")
  end

  def test_register_with_aliases
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class, aliases: ["node", "no"])

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("nodes")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("node")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("no")
  end

  def test_register_overwrites_existing_registration
    handler_class1 = Class.new
    handler_class2 = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", handler_class1)
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", handler_class2)

    handler = Pvectl::Commands::Get::ResourceRegistry.for("nodes")
    assert_instance_of handler_class2, handler
  end

  def test_register_with_symbol_aliases
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("containers", mock_handler_class, aliases: [:ct, :lxc])

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("ct")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("lxc")
  end

  # ---------------------------
  # .for() Method
  # ---------------------------

  def test_for_returns_handler_instance
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)
    handler = Pvectl::Commands::Get::ResourceRegistry.for("nodes")

    assert_instance_of mock_handler_class, handler
  end

  def test_for_returns_nil_for_unregistered_type
    handler = Pvectl::Commands::Get::ResourceRegistry.for("unknown")

    assert_nil handler
  end

  def test_for_returns_nil_for_nil_type
    handler = Pvectl::Commands::Get::ResourceRegistry.for(nil)

    assert_nil handler
  end

  def test_for_accepts_symbol_type
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)
    handler = Pvectl::Commands::Get::ResourceRegistry.for(:nodes)

    assert_instance_of mock_handler_class, handler
  end

  def test_for_returns_handler_via_alias
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class, aliases: ["node"])
    handler = Pvectl::Commands::Get::ResourceRegistry.for("node")

    assert_instance_of mock_handler_class, handler
  end

  def test_for_returns_new_instance_each_time
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)
    handler1 = Pvectl::Commands::Get::ResourceRegistry.for("nodes")
    handler2 = Pvectl::Commands::Get::ResourceRegistry.for("nodes")

    refute_same handler1, handler2
  end

  # ---------------------------
  # .registered_types() Method
  # ---------------------------

  def test_registered_types_returns_empty_array_when_no_handlers
    types = Pvectl::Commands::Get::ResourceRegistry.registered_types

    assert_kind_of Array, types
    assert_empty types
  end

  def test_registered_types_includes_primary_types
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)
    Pvectl::Commands::Get::ResourceRegistry.register("vms", mock_handler_class)

    types = Pvectl::Commands::Get::ResourceRegistry.registered_types

    assert_includes types, "nodes"
    assert_includes types, "vms"
  end

  def test_registered_types_includes_aliases
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class, aliases: ["node"])

    types = Pvectl::Commands::Get::ResourceRegistry.registered_types

    assert_includes types, "nodes"
    assert_includes types, "node"
  end

  # ---------------------------
  # .registered?() Method
  # ---------------------------

  def test_registered_returns_true_for_registered_type
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("nodes")
  end

  def test_registered_returns_false_for_unregistered_type
    refute Pvectl::Commands::Get::ResourceRegistry.registered?("unknown")
  end

  def test_registered_accepts_symbol_type
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?(:nodes)
  end

  # ---------------------------
  # .reset!() Method
  # ---------------------------

  def test_reset_clears_all_handlers
    mock_handler_class = Class.new

    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)
    Pvectl::Commands::Get::ResourceRegistry.reset!

    refute Pvectl::Commands::Get::ResourceRegistry.registered?("nodes")
    assert_empty Pvectl::Commands::Get::ResourceRegistry.registered_types
  end
end
