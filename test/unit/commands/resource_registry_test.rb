# frozen_string_literal: true

require "test_helper"

class CommandsResourceRegistryTest < Minitest::Test
  def test_base_registry_class_exists
    assert_kind_of Class, Pvectl::Commands::ResourceRegistry
  end
end

class CommandsResourceRegistryInheritanceTest < Minitest::Test
  def setup
    @registry = Class.new(Pvectl::Commands::ResourceRegistry)
  end

  def test_subclass_gets_own_handlers_hash
    handler_class = Class.new
    @registry.register("test", handler_class)
    assert @registry.registered?("test")
  end

  def test_subclass_does_not_pollute_sibling
    sibling = Class.new(Pvectl::Commands::ResourceRegistry)
    handler_class = Class.new
    @registry.register("test", handler_class)
    refute sibling.registered?("test")
  end

  def test_register_with_aliases
    handler_class = Class.new
    @registry.register("nodes", handler_class, aliases: ["node"])
    assert @registry.registered?("node")
  end

  def test_for_returns_instance
    handler_class = Class.new
    @registry.register("vms", handler_class)
    assert_instance_of handler_class, @registry.for("vms")
  end

  def test_for_returns_nil_for_unknown
    assert_nil @registry.for("unknown")
  end

  def test_for_returns_nil_for_nil
    assert_nil @registry.for(nil)
  end

  def test_registered_types
    handler_class = Class.new
    @registry.register("a", handler_class, aliases: ["b"])
    assert_includes @registry.registered_types, "a"
    assert_includes @registry.registered_types, "b"
  end

  def test_reset_clears_handlers
    handler_class = Class.new
    @registry.register("a", handler_class)
    @registry.reset!
    refute @registry.registered?("a")
  end
end
