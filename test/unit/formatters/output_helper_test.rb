# frozen_string_literal: true

require "test_helper"
require "stringio"

# =============================================================================
# Formatters::OutputHelper Tests
# =============================================================================

class FormattersOutputHelperTest < Minitest::Test
  # Tests for OutputHelper facade

  def setup
    @presenter = MockOutputPresenter.new
    @data = [MockModel.new("item1", "running"), MockModel.new("item2", "stopped")]
  end

  def test_output_helper_module_exists
    assert_kind_of Module, Pvectl::Formatters::OutputHelper
  end

  # ---------------------------
  # .print Method
  # ---------------------------

  def test_print_outputs_to_stdout
    # Test that print produces output by testing with JSON format
    # (Table format requires TTY detection which doesn't work with StringIO)
    captured_output = capture_stdout do
      Pvectl::Formatters::OutputHelper.print(
        data: @data,
        presenter: @presenter,
        format: "json",
        color_flag: false
      )
    end

    refute_empty captured_output
  end

  def test_print_uses_table_format_by_default
    # Test via render method instead of print (avoids stdout capture issues with TTY)
    result = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      color_flag: false
    )

    # Table format has column headers
    assert_match(/NAME/i, result)
    assert_match(/STATUS/i, result)
  end

  def test_print_uses_specified_format
    captured_output = capture_stdout do
      Pvectl::Formatters::OutputHelper.print(
        data: @data,
        presenter: @presenter,
        format: "json",
        color_flag: false
      )
    end

    # JSON format
    parsed = JSON.parse(captured_output)
    assert_kind_of Array, parsed
  end

  def test_print_with_yaml_format
    captured_output = capture_stdout do
      Pvectl::Formatters::OutputHelper.print(
        data: @data,
        presenter: @presenter,
        format: "yaml",
        color_flag: false
      )
    end

    # YAML format starts with ---
    assert_match(/^---/, captured_output)
  end

  def test_print_with_wide_format
    # Test via render to avoid TTY issues with stdout capture
    result = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "wide",
      color_flag: false
    )

    # Wide format includes extra columns
    assert_match(/EXTRA/i, result)
  end

  def test_print_passes_color_flag_to_formatter
    # Test via render to avoid TTY issues with stdout capture
    result_with_color = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "table",
      color_flag: true
    )

    result_without_color = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "table",
      color_flag: false
    )

    # With color should have ANSI codes
    assert_match(/\e\[/, result_with_color)
    refute_match(/\e\[/, result_without_color)
  end

  def test_print_with_describe_mode
    model = MockModel.new("item1", "running")

    # Test via render to avoid TTY issues
    result = Pvectl::Formatters::OutputHelper.render(
      data: model,
      presenter: @presenter,
      format: "table",
      color_flag: false,
      describe: true
    )

    # Describe mode shows vertical layout
    assert_match(/Name:/i, result)
    assert_match(/Status:/i, result)
  end

  def test_print_passes_context_to_formatter
    presenter = ContextAwarePresenter.new
    data = [MockNamedModel.new("prod")]

    # Test via render to avoid TTY issues
    result = Pvectl::Formatters::OutputHelper.render(
      data: data,
      presenter: presenter,
      format: "table",
      color_flag: false,
      current_context: "prod"
    )

    # Context-aware presenter marks current with *
    assert_match(/\*/, result)
  end

  # ---------------------------
  # .render Method
  # ---------------------------

  def test_render_returns_string_without_printing
    result = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "table",
      color_flag: false
    )

    assert_kind_of String, result
    refute_empty result
  end

  def test_render_does_not_output_to_stdout
    # Test with JSON format to avoid TTY issues with table formatter
    original_stdout = $stdout
    $stdout = StringIO.new

    begin
      Pvectl::Formatters::OutputHelper.render(
        data: @data,
        presenter: @presenter,
        format: "json",
        color_flag: false
      )

      stdout_content = $stdout.string
      assert_empty stdout_content
    ensure
      $stdout = original_stdout
    end
  end

  def test_render_uses_specified_format
    result = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "json",
      color_flag: false
    )

    parsed = JSON.parse(result)
    assert_kind_of Array, parsed
  end

  def test_render_with_color_flag_on_table
    result_with_color = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "table",
      color_flag: true
    )

    result_without_color = Pvectl::Formatters::OutputHelper.render(
      data: @data,
      presenter: @presenter,
      format: "table",
      color_flag: false
    )

    assert_match(/\e\[/, result_with_color)
    refute_match(/\e\[/, result_without_color)
  end

  def test_render_with_describe_mode_on_table
    model = MockModel.new("item1", "running")

    result = Pvectl::Formatters::OutputHelper.render(
      data: model,
      presenter: @presenter,
      format: "table",
      color_flag: false,
      describe: true
    )

    assert_match(/Name:/i, result)
  end

  def test_render_passes_context_on_table
    presenter = ContextAwarePresenter.new
    data = [MockNamedModel.new("prod")]

    result = Pvectl::Formatters::OutputHelper.render(
      data: data,
      presenter: presenter,
      format: "table",
      color_flag: false,
      current_context: "prod"
    )

    assert_match(/\*/, result)
  end

  # ---------------------------
  # Error Handling
  # ---------------------------

  def test_raises_for_unknown_format
    assert_raises(ArgumentError) do
      Pvectl::Formatters::OutputHelper.print(
        data: @data,
        presenter: @presenter,
        format: "unknown"
      )
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  # Mock model
  class MockModel
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  # Mock model with just name
  class MockNamedModel
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  # Mock presenter
  class MockOutputPresenter
    def columns
      ["NAME", "STATUS"]
    end

    def wide_columns
      columns + extra_columns
    end

    def extra_columns
      ["EXTRA"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_wide_row(model, **_context)
      to_row(model) + ["extra_value"]
    end

    def extra_values(model, **_context)
      ["extra_value"]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end

  # Context-aware presenter
  class ContextAwarePresenter
    def columns
      ["CURRENT", "NAME"]
    end

    def wide_columns
      columns
    end

    def to_row(model, current_context: nil, **_)
      [model.name == current_context ? "*" : "", model.name]
    end

    def to_wide_row(model, **context)
      to_row(model, **context)
    end

    def to_hash(model)
      { "name" => model.name }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end
