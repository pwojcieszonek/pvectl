# frozen_string_literal: true

require "test_helper"
require "yaml"

# =============================================================================
# Formatters::Yaml Tests
# =============================================================================

class FormattersYamlTest < Minitest::Test
  # Tests for YAML output formatting

  def setup
    @formatter = Pvectl::Formatters::Yaml.new
    @presenter = MockYamlPresenter.new
  end

  def test_yaml_class_exists
    assert_kind_of Class, Pvectl::Formatters::Yaml
  end

  def test_yaml_inherits_from_base
    assert_operator Pvectl::Formatters::Yaml, :<, Pvectl::Formatters::Base
  end

  # ---------------------------
  # Collection Formatting
  # ---------------------------

  def test_collection_renders_as_yaml_array
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter)
    parsed = YAML.safe_load(output)

    assert_kind_of Array, parsed
    assert_equal 2, parsed.length
  end

  def test_collection_contains_hash_elements
    data = [
      MockVm.new("vm-100", "running", "pve1")
    ]

    output = @formatter.format(data, @presenter)
    parsed = YAML.safe_load(output)

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
    parsed = YAML.safe_load(output)

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
    parsed = YAML.safe_load(output)

    assert_kind_of Array, parsed
    assert_empty parsed
  end

  def test_empty_collection_valid_yaml_syntax
    output = @formatter.format([], @presenter)

    # YAML empty array is "--- []\n" or just "[]"
    assert_match(/\[\]/, output)
  end

  # ---------------------------
  # Single Resource
  # ---------------------------

  def test_single_resource_renders_as_yaml_hash
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)
    parsed = YAML.safe_load(output)

    assert_kind_of Hash, parsed
    assert_equal "vm-100", parsed["name"]
    assert_equal "running", parsed["status"]
  end

  def test_single_resource_not_wrapped_in_array
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)
    parsed = YAML.safe_load(output)

    # Should be a hash, not an array
    assert_kind_of Hash, parsed
    refute_kind_of Array, parsed
  end

  # ---------------------------
  # Nil Value Handling
  # ---------------------------

  def test_nil_values_render_as_null
    data = [MockVm.new("vm-100", nil, "pve1")]

    output = @formatter.format(data, @presenter)
    parsed = YAML.safe_load(output)

    assert_nil parsed.first["status"]
  end

  def test_nil_in_yaml_uses_tilde_or_null
    data = [MockVm.new("vm-100", nil, "pve1")]

    output = @formatter.format(data, @presenter)

    # YAML represents nil as ~ or null or empty
    # The parsed result should be nil
    parsed = YAML.safe_load(output)
    assert_nil parsed.first["status"]
  end

  def test_multiple_nil_values
    data = [MockVm.new("vm-100", nil, nil)]

    output = @formatter.format(data, @presenter)
    parsed = YAML.safe_load(output)

    assert_nil parsed.first["status"]
    assert_nil parsed.first["node"]
  end

  # ---------------------------
  # Color Flag Ignored
  # ---------------------------

  def test_color_flag_is_ignored
    data = [MockVm.new("vm-100", "running", "pve1")]

    output_with_color = @formatter.format(data, @presenter, color_enabled: true)
    output_without_color = @formatter.format(data, @presenter, color_enabled: false)

    # YAML output should be identical regardless of color setting
    assert_equal output_with_color, output_without_color
  end

  def test_no_ansi_codes_in_output
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter, color_enabled: true)

    refute_match(/\e\[/, output)
  end

  # ---------------------------
  # Valid YAML Output
  # ---------------------------

  def test_output_is_valid_yaml_for_collection
    data = [
      MockVm.new("vm-100", "running", "pve1"),
      MockVm.new("vm-101", "stopped", "pve2")
    ]

    output = @formatter.format(data, @presenter)

    # Should not raise
    parsed = YAML.safe_load(output)
    assert_kind_of Array, parsed
  end

  def test_output_is_valid_yaml_for_single
    model = MockVm.new("vm-100", "running", "pve1")

    output = @formatter.format(model, @presenter)

    # Should not raise
    parsed = YAML.safe_load(output)
    assert_kind_of Hash, parsed
  end

  def test_yaml_starts_with_document_marker
    data = [MockVm.new("vm-100", "running", "pve1")]

    output = @formatter.format(data, @presenter)

    # Ruby's to_yaml typically starts with "---"
    assert_match(/^---/, output)
  end

  def test_special_characters_handled_properly
    model = MockVm.new("vm: special", "running", "node with spaces")

    output = @formatter.format(model, @presenter)

    # Should be valid YAML
    parsed = YAML.safe_load(output)
    assert_equal "vm: special", parsed["name"]
    assert_equal "node with spaces", parsed["node"]
  end

  # ---------------------------
  # Describe Mode
  # ---------------------------

  def test_describe_mode_uses_to_description
    model = MockVm.new("vm-100", "running", "pve1")
    presenter = DescribeYamlPresenter.new

    output = @formatter.format(model, presenter, describe: true)
    parsed = YAML.safe_load(output)

    # Should use to_description which has different structure
    assert_equal "vm-100", parsed["Name"]
    assert_equal "running", parsed["Status"]
    assert_kind_of Hash, parsed["System"]
  end

  def test_describe_mode_for_single_resource_only
    data = [MockVm.new("vm-100", "running", "pve1")]
    presenter = DescribeYamlPresenter.new

    output = @formatter.format(data, presenter, describe: true)
    parsed = YAML.safe_load(output)

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
  class MockYamlPresenter
    def to_hash(model)
      {
        "name" => model.name,
        "status" => model.status,
        "node" => model.node
      }
    end
  end

  # Mock presenter with to_description for describe mode
  class DescribeYamlPresenter
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
