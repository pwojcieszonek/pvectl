# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::TopPresenter Tests
# =============================================================================

# Helper class to test the TopPresenter module
class TopPresenterTestHost
  include Pvectl::Presenters::TopPresenter
end

class PresentersTopPresenterTest < Minitest::Test
  def setup
    @host = TopPresenterTestHost.new
  end

  # ---------------------------
  # Module Existence
  # ---------------------------

  def test_top_presenter_module_exists
    assert_kind_of Module, Pvectl::Presenters::TopPresenter
  end

  # ---------------------------
  # cpu_cores_value
  # ---------------------------

  def test_cpu_cores_value_returns_core_count
    resource = OpenStruct.new(maxcpu: 4)
    assert_equal "4", @host.cpu_cores_value(resource)
  end

  def test_cpu_cores_value_returns_dash_when_nil
    resource = OpenStruct.new(maxcpu: nil)
    assert_equal "-", @host.cpu_cores_value(resource)
  end

  # ---------------------------
  # cpu_usage_value
  # ---------------------------

  def test_cpu_usage_value_returns_percentage
    resource = OpenStruct.new(cpu: 0.23)
    assert_equal "23%", @host.cpu_usage_value(resource)
  end

  def test_cpu_usage_value_rounds_correctly
    resource = OpenStruct.new(cpu: 0.456)
    assert_equal "46%", @host.cpu_usage_value(resource)
  end

  def test_cpu_usage_value_returns_dash_when_nil
    resource = OpenStruct.new(cpu: nil)
    assert_equal "-", @host.cpu_usage_value(resource)
  end

  # ---------------------------
  # percent_display
  # ---------------------------

  def test_percent_display_returns_percentage
    assert_equal "50%", @host.percent_display(50, 100)
  end

  def test_percent_display_rounds_correctly
    assert_equal "33%", @host.percent_display(1, 3)
  end

  def test_percent_display_returns_dash_when_used_nil
    assert_equal "-", @host.percent_display(nil, 100)
  end

  def test_percent_display_returns_dash_when_total_nil
    assert_equal "-", @host.percent_display(50, nil)
  end

  def test_percent_display_returns_dash_when_total_zero
    assert_equal "-", @host.percent_display(50, 0)
  end

  # ---------------------------
  # percent_value
  # ---------------------------

  def test_percent_value_returns_integer
    assert_equal 50, @host.percent_value(50, 100)
  end

  def test_percent_value_rounds_correctly
    assert_equal 33, @host.percent_value(1, 3)
  end

  def test_percent_value_returns_nil_when_used_nil
    assert_nil @host.percent_value(nil, 100)
  end

  def test_percent_value_returns_nil_when_total_nil
    assert_nil @host.percent_value(50, nil)
  end

  def test_percent_value_returns_nil_when_total_zero
    assert_nil @host.percent_value(50, 0)
  end
end
