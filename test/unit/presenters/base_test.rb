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

# =============================================================================
# Presenters::Base Shared Helpers Tests
# =============================================================================

class PresentersBaseSharedHelpersTest < Minitest::Test
  def setup
    @presenter = SharedHelperPresenter.new
  end

  # ---------------------------
  # format_bytes
  # ---------------------------

  def test_format_bytes_returns_dash_for_nil
    assert_equal "-", @presenter.public_format_bytes(nil)
  end

  def test_format_bytes_returns_dash_for_zero
    assert_equal "-", @presenter.public_format_bytes(0)
  end

  def test_format_bytes_formats_bytes
    assert_equal "512 B", @presenter.public_format_bytes(512)
  end

  def test_format_bytes_formats_kib
    assert_equal "1.5 KiB", @presenter.public_format_bytes(1536)
  end

  def test_format_bytes_formats_mib
    assert_equal "1.5 MiB", @presenter.public_format_bytes(1_572_864)
  end

  def test_format_bytes_formats_gib
    assert_equal "2.5 GiB", @presenter.public_format_bytes(2_684_354_560)
  end

  # ---------------------------
  # uptime_human
  # ---------------------------

  def test_uptime_human_returns_dash_when_nil
    model = SharedModel.new(uptime: nil, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "-", @presenter.uptime_human
  end

  def test_uptime_human_returns_dash_when_zero
    model = SharedModel.new(uptime: 0, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "-", @presenter.uptime_human
  end

  def test_uptime_human_formats_days_and_hours
    model = SharedModel.new(uptime: 1_314_000, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "15d 5h", @presenter.uptime_human
  end

  def test_uptime_human_formats_hours_and_minutes
    model = SharedModel.new(uptime: 8100, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "2h 15m", @presenter.uptime_human
  end

  def test_uptime_human_formats_minutes_only
    model = SharedModel.new(uptime: 900, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "15m", @presenter.uptime_human
  end

  # ---------------------------
  # tags_array / tags_display
  # ---------------------------

  def test_tags_array_parses_semicolon_tags
    model = SharedModel.new(uptime: 0, tags: "prod;web", template: 0)
    @presenter.set_resource(model)
    assert_equal ["prod", "web"], @presenter.tags_array
  end

  def test_tags_array_returns_empty_for_nil
    model = SharedModel.new(uptime: 0, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal [], @presenter.tags_array
  end

  def test_tags_array_returns_empty_for_empty_string
    model = SharedModel.new(uptime: 0, tags: "", template: 0)
    @presenter.set_resource(model)
    assert_equal [], @presenter.tags_array
  end

  def test_tags_display_formats_comma_separated
    model = SharedModel.new(uptime: 0, tags: "prod;web", template: 0)
    @presenter.set_resource(model)
    assert_equal "prod, web", @presenter.tags_display
  end

  def test_tags_display_returns_dash_when_no_tags
    model = SharedModel.new(uptime: 0, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "-", @presenter.tags_display
  end

  # ---------------------------
  # template_display
  # ---------------------------

  def test_template_display_returns_yes_for_template
    model = SharedModel.new(uptime: 0, tags: nil, template: 1)
    @presenter.set_resource(model)
    assert_equal "yes", @presenter.template_display
  end

  def test_template_display_returns_dash_for_non_template
    model = SharedModel.new(uptime: 0, tags: nil, template: 0)
    @presenter.set_resource(model)
    assert_equal "-", @presenter.template_display
  end

  # ---------------------------
  # resource (abstract)
  # ---------------------------

  def test_resource_raises_not_implemented_on_base
    base = Pvectl::Presenters::Base.new
    error = assert_raises(NotImplementedError) do
      base.send(:resource)
    end
    assert_includes error.message, "resource must be implemented"
  end

  private

  SharedModel = Struct.new(:uptime, :tags, :template, keyword_init: true) do
    def template?
      template == 1
    end
  end

  class SharedHelperPresenter < Pvectl::Presenters::Base
    attr_reader :resource

    def set_resource(model)
      @resource = model
    end

    def columns
      ["NAME"]
    end

    def to_row(model, **_context)
      [model.to_s]
    end

    def to_hash(model)
      { "name" => model.to_s }
    end

    # Expose private method for testing
    def public_format_bytes(bytes)
      format_bytes(bytes)
    end
  end
end
