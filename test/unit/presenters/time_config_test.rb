# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Presenters::TimeConfig Tests
# =============================================================================

class PresentersTimeConfigTest < Minitest::Test
  def setup
    # 2024-05-06 13:33:20 UTC == epoch 1714998800
    @utc_epoch = 1_714_998_800
    # localtime = utc + 7200 -> wall clock the node sees: 2024-05-06 15:33:20
    @local_epoch = @utc_epoch + 7200

    @model = Pvectl::Models::TimeConfig.new(
      node_name: "pve1",
      time: @utc_epoch,
      localtime: @local_epoch,
      timezone: "Europe/Warsaw"
    )

    @presenter = Pvectl::Presenters::TimeConfig.new
  end

  # ---------------------------
  # Class
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Presenters::TimeConfig
  end

  def test_inherits_from_base
    assert Pvectl::Presenters::TimeConfig < Pvectl::Presenters::Base
  end

  # ---------------------------
  # columns
  # ---------------------------

  def test_columns
    assert_equal ["NODE", "TIMEZONE", "TIME (UTC)", "LOCAL TIME"], @presenter.columns
  end

  # ---------------------------
  # to_row
  # ---------------------------

  def test_to_row_returns_row_matching_columns
    row = @presenter.to_row(@model)
    assert_equal 4, row.length
    assert_equal "pve1", row[0]
    assert_equal "Europe/Warsaw", row[1]
    # UTC display: render with strftime via Time.at(time).utc
    assert_equal Time.at(@utc_epoch).utc.strftime("%Y-%m-%d %H:%M:%S"), row[2]
    # Local time displayed: render localtime as a UTC string (wall clock the node sees)
    assert_equal Time.at(@local_epoch).utc.strftime("%Y-%m-%d %H:%M:%S"), row[3]
  end

  def test_to_row_handles_missing_values
    model = Pvectl::Models::TimeConfig.new(node_name: "pve1")
    row = @presenter.to_row(model)
    assert_equal "pve1", row[0]
    assert_equal "-", row[1]
    assert_equal "-", row[2]
    assert_equal "-", row[3]
  end

  # ---------------------------
  # to_hash
  # ---------------------------

  def test_to_hash_returns_hash_with_string_keys
    hash = @presenter.to_hash(@model)
    assert_kind_of Hash, hash
    assert_equal "pve1", hash["node"]
    assert_equal "Europe/Warsaw", hash["timezone"]
    assert_equal @utc_epoch, hash["time"]
    assert_equal @local_epoch, hash["localtime"]
  end
end
