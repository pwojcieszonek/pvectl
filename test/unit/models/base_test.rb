# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::Base Tests
# =============================================================================

class ModelsBaseTest < Minitest::Test
  # Tests for the abstract base model class

  def test_base_class_exists
    assert_kind_of Class, Pvectl::Models::Base
  end

  def test_initialize_accepts_empty_hash
    model = Pvectl::Models::Base.new({})
    assert_instance_of Pvectl::Models::Base, model
  end

  def test_initialize_accepts_no_arguments
    model = Pvectl::Models::Base.new
    assert_instance_of Pvectl::Models::Base, model
  end

  def test_initialize_converts_string_keys_to_symbols
    # Verify via subclass since attributes is protected
    subclass = Class.new(Pvectl::Models::Base) do
      def test_keys
        attributes.keys
      end
    end

    model = subclass.new("name" => "test", "status" => "running")
    assert_includes model.test_keys, :name
    assert_includes model.test_keys, :status
    refute_includes model.test_keys, "name"
  end

  def test_initialize_preserves_symbol_keys
    subclass = Class.new(Pvectl::Models::Base) do
      def test_keys
        attributes.keys
      end
    end

    model = subclass.new(name: "test", status: "running")
    assert_includes model.test_keys, :name
    assert_includes model.test_keys, :status
  end

  def test_attributes_are_protected
    model = Pvectl::Models::Base.new(name: "test")
    refute model.respond_to?(:attributes)
  end

  def test_subclass_can_access_attributes
    subclass = Class.new(Pvectl::Models::Base) do
      def get_name
        attributes[:name]
      end
    end

    model = subclass.new(name: "test")
    assert_equal "test", model.get_name
  end
end
