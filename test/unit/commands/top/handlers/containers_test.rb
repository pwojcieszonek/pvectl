# frozen_string_literal: true

require "test_helper"

class TopHandlersContainersTest < Minitest::Test
  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Top::Handlers::Containers
  end

  def test_list_delegates_to_get_handler
    ct = Pvectl::Models::Container.new(
      vmid: 200, name: "db", status: "running", node: "pve1",
      cpu: 0.1, maxcpu: 2, mem: 1_073_741_824, maxmem: 2_147_483_648
    )
    mock_get_handler = Minitest::Mock.new
    mock_get_handler.expect :list, [ct], [], sort: nil
    handler = Pvectl::Commands::Top::Handlers::Containers.new(get_handler: mock_get_handler)
    result = handler.list(sort: nil)
    assert_equal [ct], result
    mock_get_handler.verify
  end

  def test_presenter_returns_top_container
    handler = Pvectl::Commands::Top::Handlers::Containers.new(get_handler: Object.new)
    assert_instance_of Pvectl::Presenters::TopContainer, handler.presenter
  end
end
