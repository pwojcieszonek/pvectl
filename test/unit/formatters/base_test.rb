# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Formatters::Base Tests
# =============================================================================

class FormattersBaseTest < Minitest::Test
  # Tests for the abstract base formatter class

  def test_base_class_exists
    assert_kind_of Class, Pvectl::Formatters::Base
  end

  def test_format_raises_not_implemented_error
    base = Pvectl::Formatters::Base.new
    presenter = MockPresenter.new

    error = assert_raises(NotImplementedError) do
      base.format([], presenter)
    end

    assert_includes error.message, "format must be implemented"
  end

  def test_format_method_signature_accepts_required_parameters
    base = Pvectl::Formatters::Base.new
    presenter = MockPresenter.new

    # Should accept data and presenter without error (implementation error expected)
    assert_raises(NotImplementedError) do
      base.format([{ name: "test" }], presenter)
    end
  end

  def test_format_method_signature_accepts_color_enabled_option
    base = Pvectl::Formatters::Base.new
    presenter = MockPresenter.new

    assert_raises(NotImplementedError) do
      base.format([], presenter, color_enabled: true)
    end
  end

  def test_format_method_signature_accepts_context_kwargs
    base = Pvectl::Formatters::Base.new
    presenter = MockPresenter.new

    assert_raises(NotImplementedError) do
      base.format([], presenter, color_enabled: true, current_context: "prod")
    end
  end

  # ---------------------------
  # Helper Methods (Protected)
  # ---------------------------

  def test_collection_helper_returns_true_for_array
    base = TestableFormatter.new
    assert base.test_collection?([1, 2, 3])
  end

  def test_collection_helper_returns_false_for_single_object
    base = TestableFormatter.new
    refute base.test_collection?(Object.new)
  end

  def test_collection_helper_returns_false_for_hash
    base = TestableFormatter.new
    refute base.test_collection?({ name: "test" })
  end

  def test_collection_helper_returns_true_for_empty_array
    base = TestableFormatter.new
    assert base.test_collection?([])
  end

  def test_normalize_nil_returns_placeholder_for_nil
    base = TestableFormatter.new
    assert_equal "-", base.test_normalize_nil(nil)
  end

  def test_normalize_nil_returns_value_when_not_nil
    base = TestableFormatter.new
    assert_equal "test", base.test_normalize_nil("test")
  end

  def test_normalize_nil_accepts_custom_placeholder
    base = TestableFormatter.new
    assert_equal "N/A", base.test_normalize_nil(nil, "N/A")
  end

  def test_normalize_nil_returns_zero_unchanged
    base = TestableFormatter.new
    assert_equal 0, base.test_normalize_nil(0)
  end

  def test_normalize_nil_returns_false_unchanged
    base = TestableFormatter.new
    assert_equal false, base.test_normalize_nil(false)
  end

  def test_normalize_nil_returns_empty_string_unchanged
    base = TestableFormatter.new
    assert_equal "", base.test_normalize_nil("")
  end

  private

  # Mock presenter for testing base class
  class MockPresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model[:name], model[:status]]
    end

    def to_hash(model)
      { "name" => model[:name], "status" => model[:status] }
    end
  end

  # Testable subclass to access protected methods
  class TestableFormatter < Pvectl::Formatters::Base
    def test_collection?(data)
      collection?(data)
    end

    def test_normalize_nil(value, placeholder = "-")
      normalize_nil(value, placeholder)
    end
  end
end
