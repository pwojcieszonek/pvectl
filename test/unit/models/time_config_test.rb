# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::TimeConfig Tests
# =============================================================================

class ModelsTimeConfigTest < Minitest::Test
  def setup
    @attrs = {
      node_name: "pve1",
      time: 1_715_000_000,
      localtime: 1_715_007_200,
      timezone: "Europe/Warsaw"
    }
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Models::TimeConfig
  end

  def test_inherits_from_base
    assert Pvectl::Models::TimeConfig < Pvectl::Models::Base
  end

  # ---------------------------
  # Attribute Access
  # ---------------------------

  def test_node_name_attribute
    model = Pvectl::Models::TimeConfig.new(@attrs)
    assert_equal "pve1", model.node_name
  end

  def test_time_attribute
    model = Pvectl::Models::TimeConfig.new(@attrs)
    assert_equal 1_715_000_000, model.time
  end

  def test_localtime_attribute
    model = Pvectl::Models::TimeConfig.new(@attrs)
    assert_equal 1_715_007_200, model.localtime
  end

  def test_timezone_attribute
    model = Pvectl::Models::TimeConfig.new(@attrs)
    assert_equal "Europe/Warsaw", model.timezone
  end

  def test_handles_missing_attributes
    model = Pvectl::Models::TimeConfig.new(node_name: "pve1")
    assert_equal "pve1", model.node_name
    assert_nil model.time
    assert_nil model.localtime
    assert_nil model.timezone
  end

  def test_handles_empty_attributes
    model = Pvectl::Models::TimeConfig.new({})
    assert_nil model.node_name
    assert_nil model.time
    assert_nil model.localtime
    assert_nil model.timezone
  end
end
