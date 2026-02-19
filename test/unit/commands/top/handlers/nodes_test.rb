# frozen_string_literal: true

require "test_helper"

class TopHandlersNodesTest < Minitest::Test
  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Top::Handlers::Nodes
  end

  def test_list_delegates_to_get_handler
    node = Pvectl::Models::Node.new(
      name: "pve1", status: "online", cpu: 0.23, maxcpu: 16,
      mem: 48_535_150_182, maxmem: 137_438_953_472,
      disk: 1_288_490_188_800, maxdisk: 4_398_046_511_104,
      uptime: 3_898_800
    )
    mock_get_handler = Minitest::Mock.new
    mock_get_handler.expect :list, [node], [], sort: "cpu"
    handler = Pvectl::Commands::Top::Handlers::Nodes.new(get_handler: mock_get_handler)
    result = handler.list(sort: "cpu")
    assert_equal [node], result
    mock_get_handler.verify
  end

  def test_presenter_returns_top_node
    handler = Pvectl::Commands::Top::Handlers::Nodes.new(get_handler: Object.new)
    assert_instance_of Pvectl::Presenters::TopNode, handler.presenter
  end
end
