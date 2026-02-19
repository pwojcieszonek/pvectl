# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Formatters::Registry Tests
# =============================================================================

class FormattersRegistryTest < Minitest::Test
  # Tests for formatter registry (format name to class mapping)

  def test_registry_class_exists
    assert_kind_of Class, Pvectl::Formatters::Registry
  end

  # ---------------------------
  # Format Lookup - .for()
  # ---------------------------

  def test_for_table_returns_table_formatter
    formatter = Pvectl::Formatters::Registry.for("table")
    assert_instance_of Pvectl::Formatters::Table, formatter
  end

  def test_for_wide_returns_wide_formatter
    formatter = Pvectl::Formatters::Registry.for("wide")
    assert_instance_of Pvectl::Formatters::Wide, formatter
  end

  def test_for_json_returns_json_formatter
    formatter = Pvectl::Formatters::Registry.for("json")
    assert_instance_of Pvectl::Formatters::Json, formatter
  end

  def test_for_yaml_returns_yaml_formatter
    formatter = Pvectl::Formatters::Registry.for("yaml")
    assert_instance_of Pvectl::Formatters::Yaml, formatter
  end

  def test_for_accepts_symbol_format_name
    formatter = Pvectl::Formatters::Registry.for(:table)
    assert_instance_of Pvectl::Formatters::Table, formatter
  end

  def test_for_accepts_string_format_name
    formatter = Pvectl::Formatters::Registry.for("json")
    assert_instance_of Pvectl::Formatters::Json, formatter
  end

  # ---------------------------
  # Unknown Format Error
  # ---------------------------

  def test_for_unknown_format_raises_argument_error
    error = assert_raises(ArgumentError) do
      Pvectl::Formatters::Registry.for("unknown")
    end

    assert_includes error.message, "Unknown format"
    assert_includes error.message, "unknown"
  end

  def test_for_empty_string_raises_argument_error
    assert_raises(ArgumentError) do
      Pvectl::Formatters::Registry.for("")
    end
  end

  def test_for_nil_format_raises_argument_error
    # nil.to_s is "", which is unknown
    assert_raises(ArgumentError) do
      Pvectl::Formatters::Registry.for(nil)
    end
  end

  def test_for_uppercase_format_raises_argument_error
    # Format names are case-sensitive (lowercase only)
    assert_raises(ArgumentError) do
      Pvectl::Formatters::Registry.for("TABLE")
    end
  end

  def test_for_mixed_case_format_raises_argument_error
    assert_raises(ArgumentError) do
      Pvectl::Formatters::Registry.for("Json")
    end
  end

  # ---------------------------
  # Available Formats - .available_formats()
  # ---------------------------

  def test_available_formats_returns_array
    formats = Pvectl::Formatters::Registry.available_formats
    assert_kind_of Array, formats
  end

  def test_available_formats_includes_table
    formats = Pvectl::Formatters::Registry.available_formats
    assert_includes formats, "table"
  end

  def test_available_formats_includes_wide
    formats = Pvectl::Formatters::Registry.available_formats
    assert_includes formats, "wide"
  end

  def test_available_formats_includes_json
    formats = Pvectl::Formatters::Registry.available_formats
    assert_includes formats, "json"
  end

  def test_available_formats_includes_yaml
    formats = Pvectl::Formatters::Registry.available_formats
    assert_includes formats, "yaml"
  end

  def test_available_formats_has_four_formats
    formats = Pvectl::Formatters::Registry.available_formats
    assert_equal 4, formats.length
  end

  # ---------------------------
  # Format Support Check - .supported?()
  # ---------------------------

  def test_supported_returns_true_for_table
    assert Pvectl::Formatters::Registry.supported?("table")
  end

  def test_supported_returns_true_for_wide
    assert Pvectl::Formatters::Registry.supported?("wide")
  end

  def test_supported_returns_true_for_json
    assert Pvectl::Formatters::Registry.supported?("json")
  end

  def test_supported_returns_true_for_yaml
    assert Pvectl::Formatters::Registry.supported?("yaml")
  end

  def test_supported_returns_false_for_unknown
    refute Pvectl::Formatters::Registry.supported?("unknown")
  end

  def test_supported_returns_false_for_empty_string
    refute Pvectl::Formatters::Registry.supported?("")
  end

  def test_supported_accepts_symbol
    assert Pvectl::Formatters::Registry.supported?(:json)
  end

  def test_supported_is_case_sensitive
    refute Pvectl::Formatters::Registry.supported?("TABLE")
    refute Pvectl::Formatters::Registry.supported?("JSON")
  end

  # ---------------------------
  # Formatter Instances
  # ---------------------------

  def test_for_returns_new_instance_each_time
    formatter1 = Pvectl::Formatters::Registry.for("table")
    formatter2 = Pvectl::Formatters::Registry.for("table")

    refute_same formatter1, formatter2
  end

  def test_all_formatters_respond_to_format
    Pvectl::Formatters::Registry.available_formats.each do |format_name|
      formatter = Pvectl::Formatters::Registry.for(format_name)
      assert_respond_to formatter, :format, "#{format_name} formatter should respond to :format"
    end
  end
end

# =============================================================================
# Formatters::Registry Tests - FORMATS Constant
# =============================================================================

class FormattersRegistryFormatsConstantTest < Minitest::Test
  # Tests for the FORMATS constant

  def test_formats_constant_is_frozen
    assert Pvectl::Formatters::Registry::FORMATS.frozen?
  end

  def test_formats_constant_maps_strings_to_classes
    formats = Pvectl::Formatters::Registry::FORMATS

    formats.each do |name, klass|
      assert_kind_of String, name
      assert_kind_of Class, klass
    end
  end

  def test_formats_classes_inherit_from_base
    formats = Pvectl::Formatters::Registry::FORMATS

    formats.each_value do |klass|
      assert_operator klass, :<, Pvectl::Formatters::Base
    end
  end
end
