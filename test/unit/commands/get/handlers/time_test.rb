# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Time Tests
# =============================================================================

class GetHandlersTimeTest < Minitest::Test
  def setup
    @pve1_time = Pvectl::Models::TimeConfig.new(
      node_name: "pve1",
      time: 1_715_000_000,
      localtime: 1_715_007_200,
      timezone: "Europe/Warsaw"
    )

    @pve2_time = Pvectl::Models::TimeConfig.new(
      node_name: "pve2",
      time: 1_715_000_010,
      localtime: 1_715_007_210,
      timezone: "UTC"
    )

    @pve3_offline = Pvectl::Models::Node.new(name: "pve3", status: "offline")
    @pve1_node = Pvectl::Models::Node.new(name: "pve1", status: "online")
    @pve2_node = Pvectl::Models::Node.new(name: "pve2", status: "online")
  end

  # ---------------------------
  # Class
  # ---------------------------

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Time
  end

  def test_handler_includes_resource_handler
    handler = build_handler(time_models: [@pve1_time], nodes: [@pve1_node])
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  # ---------------------------
  # list (with --node)
  # ---------------------------

  def test_list_with_node_filter_returns_single_time_config
    handler = build_handler(time_models: [@pve1_time], nodes: [@pve1_node, @pve2_node])

    result = handler.list(node: "pve1")

    assert_kind_of Array, result
    assert_equal 1, result.length
    assert_equal "pve1", result.first.node_name
    assert_equal "Europe/Warsaw", result.first.timezone
  end

  def test_list_with_unknown_node_raises_not_found
    handler = build_handler(time_models: [], nodes: [@pve1_node])

    assert_raises Pvectl::ResourceNotFoundError do
      handler.list(node: "bogus")
    end
  end

  # ---------------------------
  # list (without --node, iterates online nodes)
  # ---------------------------

  def test_list_without_node_returns_all_online_nodes_time
    handler = build_handler(
      time_models: [@pve1_time, @pve2_time],
      nodes: [@pve1_node, @pve2_node, @pve3_offline]
    )

    result = handler.list

    assert_equal 2, result.length
    names = result.map(&:node_name).sort
    assert_equal ["pve1", "pve2"], names
  end

  def test_list_skips_offline_nodes
    handler = build_handler(
      time_models: [@pve1_time],
      nodes: [@pve1_node, @pve3_offline]
    )

    result = handler.list

    assert_equal 1, result.length
    assert_equal "pve1", result.first.node_name
  end

  def test_list_handles_unreachable_node_gracefully
    # When fetch raises for a node, it should be skipped rather than aborting.
    time_repo = MockTimeRepo.new([@pve1_time])
    time_repo.failing_nodes << "pve2"
    node_repo = MockNodeRepo.new([@pve1_node, @pve2_node])

    handler = Pvectl::Commands::Get::Handlers::Time.new(
      repository: time_repo, node_repository: node_repo
    )

    result = handler.list
    assert_equal 1, result.length
    assert_equal "pve1", result.first.node_name
  end

  # ---------------------------
  # presenter
  # ---------------------------

  def test_presenter_returns_time_config_presenter
    handler = build_handler(time_models: [@pve1_time], nodes: [@pve1_node])
    assert_kind_of Pvectl::Presenters::TimeConfig, handler.presenter
  end

  private

  def build_handler(time_models:, nodes:)
    time_repo = MockTimeRepo.new(time_models)
    node_repo = MockNodeRepo.new(nodes)
    Pvectl::Commands::Get::Handlers::Time.new(
      repository: time_repo, node_repository: node_repo
    )
  end

  class MockTimeRepo
    attr_accessor :failing_nodes

    def initialize(time_models)
      @by_name = time_models.each_with_object({}) { |m, h| h[m.node_name] = m }
      @failing_nodes = []
    end

    def fetch(node_name)
      raise StandardError, "unreachable" if @failing_nodes.include?(node_name)

      @by_name[node_name] || raise(StandardError, "not found")
    end
  end

  class MockNodeRepo
    def initialize(nodes)
      @nodes = nodes
    end

    def list(**_kwargs)
      @nodes
    end

    def get(name, **_kwargs)
      @nodes.find { |n| n.name == name }
    end
  end
end
