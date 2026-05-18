# frozen_string_literal: true

require "test_helper"

class PresentersSubscriptionTest < Minitest::Test
  def setup
    @active = Pvectl::Models::Subscription.new(
      node: "pve1",
      status: "active",
      level: "c",
      productname: "Proxmox VE Community Subscription",
      key: "pve1c-1234567890",
      nextduedate: "2026-12-01",
      regdate: "2025-12-01",
      checktime: 1_733_011_200,
      serverid: "ABCDEF1234567890",
      sockets: 1
    )

    @missing = Pvectl::Models::Subscription.new(
      node: "pve2",
      status: "notfound",
      message: "no subscription"
    )

    @presenter = Pvectl::Presenters::Subscription.new
  end

  def test_columns_returns_expected_headers
    assert_equal %w[NODE LEVEL STATUS NEXTDUEDATE KEY], @presenter.columns
  end

  def test_extra_columns_for_wide
    assert_equal %w[PRODUCT REGDATE SERVERID], @presenter.extra_columns
  end

  def test_to_row_masks_key_in_default_view
    row = @presenter.to_row(@active)

    assert_equal "pve1", row[0]
    assert_equal "c", row[1]
    assert_equal "active", row[2]
    assert_equal "2026-12-01", row[3]
    # Mask preserves prefix "pve1c-" and last 4 chars "7890" with stars in between.
    refute_includes row[4], "1234567890"
    assert_match(/\Apve1c-\*+7890\z/, row[4])
  end

  def test_to_row_shows_dash_when_no_key
    row = @presenter.to_row(@missing)

    assert_equal "pve2", row[0]
    assert_equal "-", row[1]
    assert_equal "notfound", row[2]
    assert_equal "-", row[3]
    assert_equal "-", row[4]
  end

  def test_to_wide_row_reveals_full_key
    row = @presenter.to_wide_row(@active)

    assert_equal "pve1c-1234567890", row[4]
    # Extras appended after key column
    assert_equal "Proxmox VE Community Subscription", row[5]
    assert_equal "2025-12-01", row[6]
    assert_equal "ABCDEF1234567890", row[7]
  end

  def test_to_hash_includes_full_key_and_metadata
    hash = @presenter.to_hash(@active)

    assert_equal "pve1", hash["node"]
    assert_equal "active", hash["status"]
    assert_equal "pve1c-1234567890", hash["key"]
    assert_equal "Proxmox VE Community Subscription", hash["product"]
    assert_equal "2026-12-01", hash["next_due_date"]
    assert_equal 1, hash["sockets"]
  end

  def test_to_description_includes_masked_key
    desc = @presenter.to_description(@active)

    assert_equal "pve1", desc["Node"]
    assert_equal "active", desc["Status"]
    refute_equal "pve1c-1234567890", desc["Key"]
    assert_match(/\Apve1c-\*+7890\z/, desc["Key"])
  end

  def test_checktime_display_formats_unix_timestamp
    assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC\z/, @presenter.to_description(@active)["Last Check"])
  end

  def test_checktime_display_returns_dash_when_zero
    sub = Pvectl::Models::Subscription.new(node: "pve1", checktime: 0)
    assert_equal "-", @presenter.to_description(sub)["Last Check"]
  end

  def test_masked_key_handles_short_keys
    short = Pvectl::Models::Subscription.new(node: "pve1", key: "abcdef")
    @presenter.to_row(short)
    assert_equal "abcdef", @presenter.masked_key
  end
end
