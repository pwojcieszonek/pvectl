# frozen_string_literal: true

require "test_helper"
require "json"

# =============================================================================
# Formatters::Json Tests
# =============================================================================

class FormattersJsonTest < Minitest::Test
  # Tests for JSON output formatting

  def setup
    @formatter = Pvectl::Formatters::Json.new
    @presenter = MockJsonPresenter.new
  end

  def test_json_class_exists
    assert_kind_of Class, Pvectl::Formatters::Json
  end

  def test_json_inherits_from_base
    assert_operator Pvectl::Formatters::Json, :<, Pvectl::Formatters::Base
  end

  # ---------------------------
  # Collection Formatting
  # ---------------------------

  def test_collection_renders_as_json_array
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter)
    parsed = JSON.parse(output)

    assert_kind_of Array, parsed
    assert_equal 2, parsed.length
  end

  def test_collection_contains_hash_elements
    data = [
      MockVm.new("vm-100", "running", "pve1")
    ]

    output = @formatter.format(data, @presenter)
    parsed = JSON.parse(output)

    assert_kind_of Hash, parsed.first
    assert_equal "vm-100", parsed.first["name"]
    assert_equal "running", parsed.first["status"]
    assert_equal "pve1", parsed.first["node"]
  end

  def test_collection_preserves_all_data
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2"),
      MockVm.new("vm-102", "paused", "pve3")
    ]

    output = @formatter.format(data, @presenter)
    parsed = JSON.parse(output)

    names = parsed.map { |h| h["name"] }
    assert_includes names, "vm-100"
    assert_includes names, "vm-101"
    assert_includes names, "vm-102"
  end

  # ---------------------------
  # Empty Collection
  # ---------------------------

  def test_empty_collection_returns_empty_array
    output = @formatter.format([], @presenter)

    assert_equal "[]", output.strip
  end

  def test_empty_collection_is_valid_json
    output = @formatter.format([], @presenter)
    parsed = JSON.parse(output)

    assert_kind_of Array, parsed
    assert_empty parsed
  end

  # ---------------------------
  # Single Resource
  # ---------------------------

  def test_single_resource_renders_as_json_object
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)
    parsed = JSON.parse(output)

    assert_kind_of Hash, parsed
    assert_equal "vm-100", parsed["name"]
    assert_equal "running", parsed["status"]
  end

  def test_single_resource_not_wrapped_in_array
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)
    parsed = JSON.parse(output)

    # Should be a hash, not an array containing a hash
    assert_kind_of Hash, parsed
    refute_kind_of Array, parsed
  end

  # ---------------------------
  # Nil Value Handling
  # ---------------------------

  def test_nil_values_render_as_null
    data = [MockVm.new("vm-100", nil, "pve1")]

    output = @formatter.format(data, @presenter)
    parsed = JSON.parse(output)

    assert_nil parsed.first["status"]
  end

  def test_nil_in_single_resource_renders_as_null
    model = MockVm.new("vm-100", "running", nil)

    output = @formatter.format(model, @presenter)
    parsed = JSON.parse(output)

    assert_nil parsed["node"]
  end

  def test_multiple_nil_values
    data = [MockVm.new("vm-100", nil, nil)]

    output = @formatter.format(data, @presenter)
    parsed = JSON.parse(output)

    assert_nil parsed.first["status"]
    assert_nil parsed.first["node"]
  end

  # ---------------------------
  # Pretty Print
  # ---------------------------

  def test_output_is_pretty_printed
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter)

    # Pretty print has multiple lines with indentation
    assert_operator output.lines.count, :>, 1
    assert_match(/^\s+/, output) # Has indentation
  end

  def test_pretty_print_uses_proper_indentation
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter)

    # Should have consistent indentation
    lines = output.lines
    indented_lines = lines.select { |l| l.start_with?("  ") }
    refute_empty indented_lines, "Should have indented lines for pretty print"
  end

  # ---------------------------
  # Color Flag Ignored
  # ---------------------------

  def test_color_flag_is_ignored
    data = [MockVm.new("vm-100", "running", "pve1")]

    output_with_color = @formatter.format(data, @presenter, color_enabled: true)
    output_without_color = @formatter.format(data, @presenter, color_enabled: false)

    # JSON output should be identical regardless of color setting
    assert_equal output_with_color, output_without_color
  end

  def test_no_ansi_codes_in_output
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: true)

    refute_match(/\e\[/, output)
  end

  # ---------------------------
  # Valid JSON Output
  # ---------------------------

  def test_output_is_valid_json_for_collection
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter)

    # Should not raise
    parsed = JSON.parse(output)
    assert_kind_of Array, parsed
  end

  def test_output_is_valid_json_for_single
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)

    # Should not raise
    parsed = JSON.parse(output)
    assert_kind_of Hash, parsed
  end

  def test_special_characters_are_escaped
    model = MockVm.new("vm-\"special\"", "running", "node\nwith\nnewlines")

    output = @formatter.format(model, @presenter)

    # Should be valid JSON (escapes handled properly)
    parsed = JSON.parse(output)
    assert_equal "vm-\"special\"", parsed["name"]
    assert_equal "node\nwith\nnewlines", parsed["node"]
  end

  # ---------------------------
  # Describe Mode
  # ---------------------------

  def test_describe_mode_uses_to_description
    model = MockVm.new("vm-100", "running", "pve1")
    presenter = DescribeJsonPresenter.new

    output = @formatter.format(model, presenter, describe: true)
    parsed = JSON.parse(output)

    # Should use to_description which has different structure
    assert_equal "vm-100", parsed["Name"]
    assert_equal "running", parsed["Status"]
    assert_kind_of Hash, parsed["System"]
  end

  def test_describe_mode_for_single_resource_only
    data = [MockVm.new("vm-100", "running", "pve1")]
    presenter = DescribeJsonPresenter.new

    output = @formatter.format(data, presenter, describe: true)
    parsed = JSON.parse(output)

    # Collections still use to_hash, not to_description
    assert_kind_of Array, parsed
    assert_equal "vm-100", parsed.first["name"]
  end

  private

  # Mock VM model
  class MockVm
    attr_reader :name, :status, :node

    def initialize(name, status, node)
      @name = name
      @status = status
      @node = node
    end
  end

  # Mock presenter
  class MockJsonPresenter
    def to_hash(model)
      {
        "name" => model.name,
        "status" => model.status,
        "node" => model.node
      }
    end
  end

  # Mock presenter with to_description for describe mode
  class DescribeJsonPresenter
    def to_hash(model)
      {
        "name" => model.name,
        "status" => model.status,
        "node" => model.node
      }
    end

    def to_description(model)
      {
        "Name" => model.name,
        "Status" => model.status,
        "System" => {
          "Version" => "8.3.2",
          "Node" => model.node
        }
      }
    end
  end
end
