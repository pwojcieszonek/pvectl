# frozen_string_literal: true

require "test_helper"

class TopHandlersVmsTest < Minitest::Test
  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Top::Handlers::Vms
  end

  def test_list_delegates_to_get_handler
    vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "web", status: "running", node: "pve1",
      cpu: 0.5, maxcpu: 4, mem: 2_147_483_648, maxmem: 4_294_967_296
    )
    mock_get_handler = Minitest::Mock.new
    mock_get_handler.expect :list, [vm], [], sort: nil
    handler = Pvectl::Commands::Top::Handlers::Vms.new(get_handler: mock_get_handler)
    result = handler.list(sort: nil)
    assert_equal [vm], result
    mock_get_handler.verify
  end

  def test_presenter_returns_top_vm
    handler = Pvectl::Commands::Top::Handlers::Vms.new(get_handler: Object.new)
    assert_instance_of Pvectl::Presenters::TopVm, handler.presenter
  end
end
