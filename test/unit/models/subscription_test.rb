# frozen_string_literal: true

require "test_helper"

class ModelsSubscriptionTest < Minitest::Test
  def setup
    @attrs = {
      node: "pve1",
      status: "active",
      level: "c",
      productname: "Proxmox VE Community Subscription",
      key: "pve1c-1234567890",
      nextduedate: "2026-12-01",
      regdate: "2025-12-01",
      checktime: 1_733_011_200,
      serverid: "ABCDEF1234567890",
      sockets: 1,
      url: "https://shop.proxmox.com",
      message: "OK",
      signature: nil
    }
  end

  def test_class_exists_and_inherits_from_base
    assert_kind_of Class, Pvectl::Models::Subscription
    assert Pvectl::Models::Subscription < Pvectl::Models::Base
  end

  def test_initializes_all_attributes
    sub = Pvectl::Models::Subscription.new(@attrs)

    assert_equal "pve1", sub.node
    assert_equal "active", sub.status
    assert_equal "c", sub.level
    assert_equal "Proxmox VE Community Subscription", sub.productname
    assert_equal "pve1c-1234567890", sub.key
    assert_equal "2026-12-01", sub.nextduedate
    assert_equal "2025-12-01", sub.regdate
    assert_equal 1_733_011_200, sub.checktime
    assert_equal "ABCDEF1234567890", sub.serverid
    assert_equal 1, sub.sockets
    assert_equal "https://shop.proxmox.com", sub.url
    assert_equal "OK", sub.message
  end

  def test_active_predicate_true_when_status_active
    sub = Pvectl::Models::Subscription.new(status: "active")

    assert sub.active?
    refute sub.missing?
  end

  def test_active_predicate_false_when_status_other
    sub = Pvectl::Models::Subscription.new(status: "expired")

    refute sub.active?
  end

  def test_missing_predicate_true_for_notfound
    assert Pvectl::Models::Subscription.new(status: "notfound").missing?
    assert Pvectl::Models::Subscription.new(status: "new").missing?
    assert Pvectl::Models::Subscription.new(status: nil).missing?
  end

  def test_missing_predicate_false_for_active
    refute Pvectl::Models::Subscription.new(status: "active").missing?
  end

  def test_accepts_string_keys
    sub = Pvectl::Models::Subscription.new("status" => "active", "node" => "pve1")

    assert_equal "active", sub.status
    assert_equal "pve1", sub.node
  end
end
