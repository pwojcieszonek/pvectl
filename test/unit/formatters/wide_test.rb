# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Formatters::Wide Tests
# =============================================================================

class FormattersWideTest < Minitest::Test
  # Tests for wide table output formatting

  def setup
    @formatter = Pvectl::Formatters::Wide.new
    @presenter = MockWidePresenter.new
  end

  def test_wide_class_exists
    assert_kind_of Class, Pvectl::Formatters::Wide
  end

  def test_wide_inherits_from_base
    assert_operator Pvectl::Formatters::Wide, :<, Pvectl::Formatters::Base
  end

  # ---------------------------
  # Wide Column Rendering
  # ---------------------------

  def test_uses_wide_columns_instead_of_columns
    data = [MockVm.new("vm-100", "running", "pve1", 2048, 2)]

    output = @formatter.format(data, @presenter, color_enabled: false)

    # Wide columns include MEMORY and CPU
    assert_match(/MEMORY/i, output)
    assert_match(/CPU/i, output)
  end

  def test_includes_all_wide_column_data
    data = [MockVm.new("vm-100", "running", "pve1", 2048, 2)]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/vm-100/, output)
    assert_match(/2048/, output)
    assert_match(/2/, output)
  end

  def test_uses_to_wide_row_method
    data = [
      MockVm.new("vm-100", "running", "pve1", 4096, 4),
      MockVm.new("vm-101", "stopped", "pve2", 1024, 1)
    ]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/4096/, output)
    assert_match(/1024/, output)
  end

  # ---------------------------
  # Empty Collection
  # ---------------------------

  def test_empty_collection_shows_wide_headers
    output = @formatter.format([], @presenter, color_enabled: false)

    assert_match(/NAME/i, output)
    assert_match(/STATUS/i, output)
    assert_match(/NODE/i, output)
    assert_match(/MEMORY/i, output)
    assert_match(/CPU/i, output)
  end

  # ---------------------------
  # Describe Mode (Single Resource)
  # ---------------------------

  def test_describe_mode_delegates_to_table_formatter
    model = MockVm.new("vm-100", "running", "pve1", 2048, 2)

    output = @formatter.format(model, @presenter, color_enabled: false, describe: true)

    # Should show vertical layout, not wide table
    assert_match(/Name:.*vm-100/i, output)
    assert_match(/Status:.*running/i, output)
  end

  def test_wide_format_ignored_for_describe
    model = MockVm.new("vm-100", "running", "pve1", 2048, 2)

    # Even with wide formatter, describe should show standard vertical layout
    output = @formatter.format(model, @presenter, color_enabled: false, describe: true)

    # Vertical layout doesn't show table headers
    refute_match(/^NAME\s+STATUS\s+NODE/i, output)
  end

  def test_non_array_data_triggers_describe_mode
    model = MockVm.new("vm-100", "running", "pve1", 2048, 2)

    output = @formatter.format(model, @presenter, color_enabled: false)

    # Non-array should trigger describe mode via Table formatter
    assert_match(/Name:/i, output)
  end

  # ---------------------------
  # Color Support
  # ---------------------------

  def test_status_is_colored_when_enabled
    data = [MockVm.new("vm-100", "running", "pve1", 2048, 2)]

    output = @formatter.format(data, @presenter, color_enabled: true)

    assert_match(/\e\[/, output) # Contains ANSI escape
  end

  def test_no_ansi_codes_when_color_disabled
    data = [MockVm.new("vm-100", "running", "pve1", 2048, 2)]

    output = @formatter.format(data, @presenter, color_enabled: false)

    refute_match(/\e\[/, output)
  end

  # ---------------------------
  # Nil Value Handling
  # ---------------------------

  def test_nil_extra_values_render_as_dash
    data = [MockVm.new("vm-100", "running", "pve1", nil, nil)]

    output = @formatter.format(data, @presenter, color_enabled: false)

    # Nil values should be "-"
    lines = output.split("\n")
    data_line = lines.find { |l| l.include?("vm-100") }
    assert data_line, "Data line not found"
    assert_match(/-/, data_line)
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_passes_context_to_presenter
    presenter = ContextAwareWidePresenter.new
    data = [MockContext.new("prod", "production", "admin", "pve1")]

    output = @formatter.format(data, presenter, color_enabled: false, current_context: "prod")

    assert_match(/\*/, output) # Current marker
  end

  private

  # Mock VM model with extended attributes
  class MockVm
    attr_reader :name, :status, :node, :memory, :cpu

    def initialize(name, status, node, memory, cpu)
      @name = name
      @status = status
      @node = node
      @memory = memory
      @cpu = cpu
    end
  end

  # Presenter with wide columns
  class MockWidePresenter
    def columns
      ["NAME", "STATUS", "NODE"]
    end

    def wide_columns
      columns + extra_columns
    end

    def extra_columns
      ["MEMORY", "CPU"]
    end

    def to_row(model, **_context)
      [model.name, model.status, model.node]
    end

    def to_wide_row(model, **_context)
      to_row(model) + extra_values(model)
    end

    def extra_values(model, **_context)
      [model.memory, model.cpu]
    end

    def to_hash(model)
      {
        "name" => model.name,
        "status" => model.status,
        "node" => model.node
      }
    end

    def to_description(model)
      {
        "name" => model.name,
        "status" => model.status,
        "node" => model.node,
        "memory" => model.memory,
        "cpu" => model.cpu
      }
    end
  end

  # Mock context
  class MockContext
    attr_reader :name, :cluster_ref, :user_ref, :default_node

    def initialize(name, cluster_ref, user_ref, default_node)
      @name = name
      @cluster_ref = cluster_ref
      @user_ref = user_ref
      @default_node = default_node
    end
  end

  # Context-aware wide presenter
  class ContextAwareWidePresenter
    def columns
      ["CURRENT", "NAME", "CLUSTER"]
    end

    def wide_columns
      columns + ["DEFAULT-NODE"]
    end

    def extra_columns
      ["DEFAULT-NODE"]
    end

    def to_row(model, current_context: nil, **_)
      [
        model.name == current_context ? "*" : "",
        model.name,
        model.cluster_ref
      ]
    end

    def to_wide_row(model, current_context: nil, **_)
      to_row(model, current_context: current_context) + [model.default_node]
    end

    def extra_values(model, **_)
      [model.default_node]
    end

    def to_hash(model)
      { "name" => model.name, "cluster" => model.cluster_ref }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end
