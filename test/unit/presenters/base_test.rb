# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::Base Tests
# =============================================================================

class PresentersBaseTest < Minitest::Test
  # Tests for the abstract base presenter class

  def test_base_class_exists
    assert_kind_of Class, Pvectl::Presenters::Base
  end

  # ---------------------------
  # Required Methods (raise NotImplementedError)
  # ---------------------------

  def test_columns_raises_not_implemented_error
    base = Pvectl::Presenters::Base.new

    error = assert_raises(NotImplementedError) do
      base.columns
    end

    assert_includes error.message, "columns must be implemented"
  end

  def test_to_row_raises_not_implemented_error
    base = Pvectl::Presenters::Base.new
    model = Object.new

    error = assert_raises(NotImplementedError) do
      base.to_row(model)
    end

    assert_includes error.message, "to_row must be implemented"
  end

  def test_to_hash_raises_not_implemented_error
    base = Pvectl::Presenters::Base.new
    model = Object.new

    error = assert_raises(NotImplementedError) do
      base.to_hash(model)
    end

    assert_includes error.message, "to_hash must be implemented"
  end

  # ---------------------------
  # Wide Format Methods (Default Implementations)
  # ---------------------------

  def test_wide_columns_combines_columns_and_extra_columns
    presenter = TestablePresenter.new
    wide = presenter.wide_columns

    assert_equal ["NAME", "STATUS", "EXTRA1", "EXTRA2"], wide
  end

  def test_extra_columns_returns_empty_by_default
    # Use a presenter that only overrides required methods
    presenter = MinimalPresenter.new

    assert_equal [], presenter.extra_columns
  end

  def test_to_wide_row_combines_to_row_and_extra_values
    presenter = TestablePresenter.new
    model = MockModel.new("test", "running", "value1", "value2")

    wide_row = presenter.to_wide_row(model)

    assert_equal ["test", "running", "value1", "value2"], wide_row
  end

  def test_extra_values_returns_empty_by_default
    presenter = MinimalPresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    assert_equal [], presenter.extra_values(model)
  end

  # ---------------------------
  # to_description Method
  # ---------------------------

  def test_to_description_defaults_to_to_hash
    presenter = TestablePresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    description = presenter.to_description(model)
    hash = presenter.to_hash(model)

    assert_equal hash, description
  end

  def test_to_description_can_be_overridden
    presenter = DescribablePresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    description = presenter.to_description(model)

    # Custom description includes extra fields
    assert description.key?("extra_info")
    assert_equal "detailed", description["extra_info"]
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_to_row_accepts_context_kwargs
    presenter = TestablePresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    # Should not raise with context kwargs
    row = presenter.to_row(model, current_context: "prod", extra_key: "value")
    assert_kind_of Array, row
  end

  def test_to_wide_row_passes_context_to_extra_values
    presenter = ContextAwarePresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    wide_row = presenter.to_wide_row(model, highlight: true)

    # Context-aware extra_values adds marker when highlight is true
    assert_includes wide_row, "[*]"
  end

  def test_extra_values_accepts_context_kwargs
    presenter = ContextAwarePresenter.new
    model = MockModel.new("test", "running", "v1", "v2")

    # Should not raise
    extra = presenter.extra_values(model, some_option: true)
    assert_kind_of Array, extra
  end

  private

  # Mock model for testing
  class MockModel
    attr_reader :name, :status, :value1, :value2

    def initialize(name, status, value1, value2)
      @name = name
      @status = status
      @value1 = value1
      @value2 = value2
    end
  end

  # Minimal presenter that only implements required methods
  class MinimalPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end
  end

  # Full-featured testable presenter
  class TestablePresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def extra_columns
      ["EXTRA1", "EXTRA2"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def extra_values(model, **_context)
      [model.value1, model.value2]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end
  end

  # Presenter with custom to_description
  class DescribablePresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model).merge("extra_info" => "detailed")
    end
  end

  # Context-aware presenter
  class ContextAwarePresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def extra_columns
      ["MARKER"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def extra_values(model, highlight: false, **_)
      [highlight ? "[*]" : ""]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end
  end
end

# =============================================================================
# Presenters::Base Tests - Interface Contract
# =============================================================================

class PresentersBaseInterfaceTest < Minitest::Test
  # Tests verifying the interface contract for subclasses

  def test_subclass_must_implement_columns
    presenter = IncompletePresenter.new

    assert_raises(NotImplementedError) { presenter.columns }
  end

  def test_subclass_must_implement_to_row
    presenter = IncompletePresenter.new
    model = Object.new

    assert_raises(NotImplementedError) { presenter.to_row(model) }
  end

  def test_subclass_must_implement_to_hash
    presenter = IncompletePresenter.new
    model = Object.new

    assert_raises(NotImplementedError) { presenter.to_hash(model) }
  end

  def test_complete_subclass_works
    presenter = CompletePresenter.new
    model = Struct.new(:name, :status).new("test", "active")

    # All required methods work
    assert_equal ["NAME", "STATUS"], presenter.columns
    assert_equal ["test", "active"], presenter.to_row(model)
    assert_equal({ "name" => "test", "status" => "active" }, presenter.to_hash(model))
  end

  def test_complete_subclass_has_default_wide_methods
    presenter = CompletePresenter.new
    model = Struct.new(:name, :status).new("test", "active")

    # Default wide methods work (empty extra)
    assert_equal ["NAME", "STATUS"], presenter.wide_columns
    assert_equal ["test", "active"], presenter.to_wide_row(model)
    assert_equal [], presenter.extra_values(model)
  end

  private

  # Presenter that doesn't override anything
  class IncompletePresenter < Pvectl::Presenters::Base
  end

  # Presenter that implements all required methods
  class CompletePresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end
  end
end
