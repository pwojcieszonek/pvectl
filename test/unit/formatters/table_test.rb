# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Formatters::Table Tests
# =============================================================================

class FormattersTableTest < Minitest::Test
  # Tests for table output formatting

  def setup
    @formatter = Pvectl::Formatters::Table.new
    @presenter = MockVmPresenter.new
  end

  def test_table_class_exists
    assert_kind_of Class, Pvectl::Formatters::Table
  end

  def test_table_inherits_from_base
    assert_operator Pvectl::Formatters::Table, :<, Pvectl::Formatters::Base
  end

  # ---------------------------
  # Collection Formatting
  # ---------------------------

  def test_formats_collection_as_table_with_headers
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/NAME/i, output)
    assert_match(/STATUS/i, output)
    assert_match(/NODE/i, output)
  end

  def test_formats_collection_with_row_data
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/vm-100/, output)
    assert_match(/vm-101/, output)
    assert_match(/pve1/, output)
    assert_match(/pve2/, output)
  end

  def test_formats_multiple_rows
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2"),
      MockVm.new("vm-102", "paused", "pve1")
    ]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/vm-100/, output)
    assert_match(/vm-101/, output)
    assert_match(/vm-102/, output)
  end

  # ---------------------------
  # Empty Collection
  # ---------------------------

  def test_empty_collection_shows_headers_only
    output = @formatter.format([], @presenter, color_enabled: false)

    assert_match(/NAME/i, output)
    assert_match(/STATUS/i, output)
    assert_match(/NODE/i, output)
    # Should not contain any VM data
    refute_match(/vm-/, output)
  end

  def test_empty_collection_returns_valid_output
    output = @formatter.format([], @presenter, color_enabled: false)

    # Should be a non-empty string (at minimum the headers)
    refute_empty output.strip
  end

  # ---------------------------
  # Nil Value Handling
  # ---------------------------

  def test_nil_values_render_as_dash
    data = [MockVm.new("vm-100", nil, "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: false)

    assert_match(/-/, output)
  end

  def test_nil_node_renders_as_dash
    data = [MockVm.new("vm-100", "running", nil)]

    output = @formatter.format(data, @presenter, color_enabled: false)

    # The nil node should be rendered as "-"
    lines = output.split("\n")
    data_line = lines.find { |l| l.include?("vm-100") }
    assert data_line, "Data line not found"
    assert_match(/-/, data_line)
  end

  # ---------------------------
  # Describe Mode (Single Resource)
  # ---------------------------

  def test_single_resource_renders_vertical_layout
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter, color_enabled: false, describe: true)

    # Vertical layout has "Key: Value" format
    assert_match(/Name:.*vm-100/i, output)
    assert_match(/Status:.*running/i, output)
    assert_match(/Node:.*pve1/i, output)
  end

  def test_describe_mode_uses_vertical_layout
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter, color_enabled: false, describe: true)

    # Should have newlines separating key-value pairs
    assert_operator output.split("\n").length, :>=, 3
  end

  def test_non_array_data_triggers_describe_mode
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter, color_enabled: false)

    # Non-array should trigger vertical layout
    assert_match(/Name:/i, output)
  end

  def test_describe_nil_values_render_as_dash
    model = MockVm.new("vm-100", nil, nil)

    output = @formatter.format(model, @presenter, color_enabled: false, describe: true)

    assert_match(/-/, output)
  end

  # ---------------------------
  # Color Support
  # ---------------------------

  def test_status_running_colored_green_when_enabled
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: true)

    # ANSI green code is \e[32m or similar
    assert_match(/\e\[/, output) # Contains ANSI escape
  end

  def test_status_stopped_colored_red_when_enabled
    data = [MockVm.new("vm-100", "stopped", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: true)

    assert_match(/\e\[/, output) # Contains ANSI escape
  end

  def test_status_paused_colored_yellow_when_enabled
    data = [MockVm.new("vm-100", "paused", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: true)

    assert_match(/\e\[/, output) # Contains ANSI escape
  end

  def test_no_ansi_codes_when_color_disabled
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: false)

    refute_match(/\e\[/, output)
  end

  def test_describe_mode_colors_status_when_enabled
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter, color_enabled: true, describe: true)

    assert_match(/\e\[/, output) # Contains ANSI escape for status
  end

  # ---------------------------
  # Context Passing
  # ---------------------------

  def test_passes_context_to_presenter
    presenter = ContextAwarePresenter.new
    data = [MockContext.new("prod", "production", "admin")]

    output = @formatter.format(data, presenter, color_enabled: false, current_context: "prod")

    assert_match(/\*/, output) # Current marker
  end

  # ---------------------------
  # Describe Mode - Nested Hash
  # ---------------------------

  def test_describe_nested_hash_renders_as_section
    model = MockNodeDescribe.new("pve1", "online")
    presenter = NestedDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # Should have nested section with indentation
    assert_includes output, "System:"
    assert_includes output, "Version:"
    assert_includes output, "8.3.2"
  end

  def test_describe_deeply_nested_hash
    model = MockNodeDescribe.new("pve1", "online")
    presenter = NestedDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # CPU section with nested values
    assert_includes output, "CPU:"
    assert_includes output, "Cores:"
  end

  # ---------------------------
  # Describe Mode - Array of Hashes (Inline Table)
  # ---------------------------

  def test_describe_array_of_hashes_renders_as_table
    model = MockNodeDescribe.new("pve1", "online")
    presenter = TableArrayDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # Should render Services as inline table
    assert_includes output, "Services:"
    assert_includes output, "NAME"
    assert_includes output, "STATE"
    assert_includes output, "pve-cluster"
    assert_includes output, "running"
  end

  def test_describe_array_of_hashes_has_headers
    model = MockNodeDescribe.new("pve1", "online")
    presenter = TableArrayDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # Headers should be uppercase
    assert_match(/NAME.*STATE/i, output)
  end

  # ---------------------------
  # Describe Mode - Mixed Content
  # ---------------------------

  def test_describe_handles_mixed_simple_nested_and_array
    model = MockNodeDescribe.new("pve1", "online")
    presenter = MixedDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # Simple value
    assert_includes output, "Name:"
    assert_includes output, "pve1"

    # Nested hash
    assert_includes output, "System:"

    # Array of hashes
    assert_includes output, "Services:"
  end

  def test_describe_empty_array_renders_as_dash
    model = MockNodeDescribe.new("pve1", "online")
    presenter = EmptyArrayDescribePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # Empty arrays should show "-"
    assert_match(/Services:.*-/m, output)
  end

  # ---------------------------
  # humanize_key
  # ---------------------------

  def test_humanize_key_preserves_hyphenated_formatted_keys
    model = MockNodeDescribe.new("pve1", "online")
    presenter = HyphenatedKeyPresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # "Cloud-Init" should be preserved, not converted to "Cloud Init"
    assert_includes output, "Cloud-Init:"
    refute_includes output, "Cloud Init:"
  end

  def test_humanize_key_still_converts_snake_case
    model = MockNodeDescribe.new("pve1", "online")
    presenter = SnakeCaseKeyPresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    # "some_key" should become "Some Key"
    assert_includes output, "Some Key:"
  end

  # ---------------------------
  # Section Spacing
  # ---------------------------

  def test_describe_blank_line_before_simple_value_after_section
    model = MockNodeDescribe.new("pve1", "online")
    presenter = SectionSpacingPresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    lines = output.split("\n")
    # Find "Simple After:" line — should have a blank line before it
    idx = lines.index { |l| l.include?("Simple After:") }
    refute_nil idx, "Expected 'Simple After:' in output"
    assert_equal "", lines[idx - 1], "Expected blank line before 'Simple After:' (follows a section)"
  end

  def test_describe_no_blank_line_between_header_fields
    model = MockNodeDescribe.new("pve1", "online")
    presenter = SectionSpacingPresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    lines = output.split("\n")
    # "Name:" and "Status:" are both header fields — no blank line between them
    name_idx = lines.index { |l| l.include?("Name:") }
    status_idx = lines.index { |l| l.include?("Status:") }
    assert_equal name_idx + 1, status_idx, "Expected no blank line between header fields"
  end

  def test_describe_consecutive_simple_values_after_section_separated
    model = MockNodeDescribe.new("pve1", "online")
    presenter = ConsecutiveSimplePresenter.new

    output = @formatter.format(model, presenter, color_enabled: false, describe: true)

    lines = output.split("\n")
    # Both "Snapshots:" and "Pending:" should have blank lines before them
    snap_idx = lines.index { |l| l.include?("Snapshots:") }
    pend_idx = lines.index { |l| l.include?("Pending:") }
    refute_nil snap_idx
    refute_nil pend_idx
    assert_equal "", lines[snap_idx - 1], "Expected blank line before Snapshots"
    assert_equal "", lines[pend_idx - 1], "Expected blank line before Pending"
  end

  private

  # Mock VM model for testing
  class MockVm
    attr_reader :name, :status, :node

    def initialize(name, status, node)
      @name = name
      @status = status
      @node = node
    end
  end

  # Mock presenter for VMs
  class MockVmPresenter
    def columns
      ["NAME", "STATUS", "NODE"]
    end

    def to_row(model, **_context)
      [model.name, model.status, model.node]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status, "node" => model.node }
    end

    def to_description(model)
      to_hash(model)
    end
  end

  # Mock context model
  class MockContext
    attr_reader :name, :cluster_ref, :user_ref

    def initialize(name, cluster_ref, user_ref)
      @name = name
      @cluster_ref = cluster_ref
      @user_ref = user_ref
    end
  end

  # Presenter that uses context
  class ContextAwarePresenter
    def columns
      ["CURRENT", "NAME", "CLUSTER"]
    end

    def to_row(model, current_context: nil, **_)
      [
        model.name == current_context ? "*" : "",
        model.name,
        model.cluster_ref
      ]
    end

    def to_hash(model)
      { "name" => model.name, "cluster" => model.cluster_ref }
    end

    def to_description(model)
      to_hash(model)
    end
  end

  # Mock node for describe tests
  class MockNodeDescribe
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  # Presenter with nested hash in to_description
  class NestedDescribePresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      {
        "Name" => model.name,
        "Status" => model.status,
        "System" => {
          "Version" => "8.3.2",
          "Kernel" => "6.8.12-1-pve"
        },
        "CPU" => {
          "Model" => "AMD EPYC",
          "Cores" => 16,
          "Sockets" => 2
        }
      }
    end
  end

  # Presenter with array of hashes for inline table
  class TableArrayDescribePresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      {
        "Name" => model.name,
        "Services" => [
          { "Name" => "pve-cluster", "State" => "running" },
          { "Name" => "pvedaemon", "State" => "running" }
        ]
      }
    end
  end

  # Presenter with mixed content
  class MixedDescribePresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      {
        "Name" => model.name,
        "Status" => model.status,
        "System" => {
          "Version" => "8.3.2"
        },
        "Services" => [
          { "Name" => "pve-cluster", "State" => "running" }
        ]
      }
    end
  end

  # Presenter with empty array
  class EmptyArrayDescribePresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      {
        "Name" => model.name,
        "Services" => []
      }
    end
  end

  # Presenter with hyphenated key (e.g., "Cloud-Init")
  class HyphenatedKeyPresenter
    def columns = ["NAME"]
    def to_row(model, **_) = [model.name]
    def to_hash(model) = { "name" => model.name }

    def to_description(_model)
      { "Name" => "test", "Cloud-Init" => "-" }
    end
  end

  # Presenter with snake_case keys
  class SnakeCaseKeyPresenter
    def columns = ["NAME"]
    def to_row(model, **_) = [model.name]
    def to_hash(model) = { "name" => model.name }

    def to_description(_model)
      { "some_key" => "value" }
    end
  end

  # Presenter simulating section spacing: header fields, then section, then simple value
  class SectionSpacingPresenter
    def columns = ["NAME"]
    def to_row(model, **_) = [model.name]
    def to_hash(model) = { "name" => model.name }

    def to_description(_model)
      {
        "Name" => "test",
        "Status" => "running",
        "Details" => { "Version" => "1.0" },
        "Simple After" => "some value"
      }
    end
  end

  # Presenter simulating consecutive simple values after a section
  class ConsecutiveSimplePresenter
    def columns = ["NAME"]
    def to_row(model, **_) = [model.name]
    def to_hash(model) = { "name" => model.name }

    def to_description(_model)
      {
        "Name" => "test",
        "Options" => { "Boot" => "Yes" },
        "Snapshots" => "No snapshots",
        "Pending" => "No pending changes"
      }
    end
  end
end

# =============================================================================
# Formatters::Table Tests - TTY-Table Integration
# =============================================================================

class FormattersTableTtyTableTest < Minitest::Test
  # Tests for tty-table gem integration

  def setup
    @formatter = Pvectl::Formatters::Table.new
    @presenter = MockSimplePresenter.new
  end

  def test_uses_basic_renderer_without_borders
    data = [MockItem.new("item1", "active")]

    output = @formatter.format(data, @presenter, color_enabled: false)

    # Basic renderer doesn't have box-drawing characters
    refute_match(/[|+\-=]/, output.gsub(/item|active|-/i, ""))
  end

  def test_columns_are_properly_aligned
    data = [
      MockItem.new("short", "active"),
      MockItem.new("verylongname", "active")
    ]

    output = @formatter.format(data, @presenter, color_enabled: false)

    # Both rows should be formatted consistently
    assert_match(/short/, output)
    assert_match(/verylongname/, output)
  end

  private

  class MockItem
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  class MockSimplePresenter
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end
