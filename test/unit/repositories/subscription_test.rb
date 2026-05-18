# frozen_string_literal: true

require "test_helper"

class RepositoriesSubscriptionTest < Minitest::Test
  def setup
    @nodes_response = [
      { node: "pve1", status: "online" },
      { node: "pve2", status: "online" },
      { node: "pve3", status: "offline" }
    ]

    @sub_pve1 = {
      status: "active",
      level: "c",
      productname: "Proxmox VE Community Subscription",
      key: "pve1c-1234567890",
      nextduedate: "2026-12-01",
      regdate: "2025-12-01",
      checktime: 1_733_011_200,
      serverid: "ABCDEF",
      sockets: 1,
      url: "https://shop.proxmox.com"
    }

    @sub_pve2 = {
      status: "notfound",
      message: "no subscription"
    }
  end

  def test_class_exists_and_inherits_from_base
    assert_kind_of Class, Pvectl::Repositories::Subscription
    assert Pvectl::Repositories::Subscription < Pvectl::Repositories::Base
  end

  def test_list_returns_one_subscription_per_online_node
    repo = build_repo(
      "nodes" => @nodes_response,
      "nodes/pve1/subscription" => @sub_pve1,
      "nodes/pve2/subscription" => @sub_pve2
    )

    records = repo.list

    assert_equal 2, records.length
    assert records.all? { |r| r.is_a?(Pvectl::Models::Subscription) }
    nodes = records.map(&:node).sort
    assert_equal %w[pve1 pve2], nodes
  end

  def test_list_filters_by_node_when_provided
    repo = build_repo(
      "nodes/pve1/subscription" => @sub_pve1
    )

    records = repo.list(node: "pve1")

    assert_equal 1, records.length
    assert_equal "pve1", records.first.node
    assert_equal "active", records.first.status
    assert_equal "pve1c-1234567890", records.first.key
  end

  def test_list_handles_data_wrapper_in_response
    repo = build_repo(
      "nodes" => { data: @nodes_response },
      "nodes/pve1/subscription" => { data: @sub_pve1 },
      "nodes/pve2/subscription" => { data: @sub_pve2 }
    )

    records = repo.list

    assert_equal 2, records.length
    pve1 = records.find { |r| r.node == "pve1" }
    assert_equal "active", pve1.status
    assert_equal "pve1c-1234567890", pve1.key
  end

  def test_list_returns_unreachable_record_when_node_api_raises
    repo = build_repo(
      "nodes" => @nodes_response,
      "nodes/pve1/subscription" => @sub_pve1,
      "nodes/pve2/subscription" => :raise_error
    )

    records = repo.list

    assert_equal 2, records.length
    failed = records.find { |r| r.node == "pve2" }
    assert_equal "unreachable", failed.status
  end

  def test_list_skips_offline_nodes
    repo = build_repo(
      "nodes" => @nodes_response,
      "nodes/pve1/subscription" => @sub_pve1,
      "nodes/pve2/subscription" => @sub_pve2
    )

    records = repo.list
    nodes = records.map(&:node)

    refute_includes nodes, "pve3"
  end

  def test_get_returns_single_subscription_for_named_node
    repo = build_repo(
      "nodes/pve1/subscription" => @sub_pve1
    )

    record = repo.get("pve1")

    assert_instance_of Pvectl::Models::Subscription, record
    assert_equal "pve1", record.node
    assert_equal "Proxmox VE Community Subscription", record.productname
  end

  private

  def build_repo(routes)
    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      mock_resource = Object.new
      response = routes[path] || []
      mock_resource.define_singleton_method(:get) do |**_kwargs|
        raise StandardError, "boom" if response == :raise_error

        response
      end
      mock_resource
    end

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    Pvectl::Repositories::Subscription.new(mock_connection)
  end
end
