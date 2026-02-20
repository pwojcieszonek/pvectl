# frozen_string_literal: true

require "test_helper"

class GetHandlersTasksTest < Minitest::Test
  def setup
    @entry = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:000A:...", node: "pve1", type: "qmstart",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_000,
      endtime: 1_708_300_005, user: "root@pam", id: "100"
    )
  end

  def test_handler_class_exists
    assert Pvectl::Commands::Get::Handlers::Tasks
  end

  def test_handler_includes_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_service([]))
    assert_kind_of Pvectl::Commands::Get::ResourceHandler, handler
  end

  def test_list_delegates_to_service_with_defaults
    mock_svc = Minitest::Mock.new
    mock_svc.expect :list, [@entry], [],
      node: nil, vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_svc)
    result = handler.list

    assert_equal 1, result.size
    assert_equal "qmstart", result.first.type
    mock_svc.verify
  end

  def test_list_passes_node_filter
    mock_svc = Minitest::Mock.new
    mock_svc.expect :list, [@entry], [],
      node: "pve1", vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_svc)
    result = handler.list(node: "pve1")

    assert_equal 1, result.size
    mock_svc.verify
  end

  def test_list_passes_all_filters
    mock_svc = Minitest::Mock.new
    mock_svc.expect :list, [@entry], [],
      node: "pve1", vmid: nil, limit: 20, since: "2026-01-01",
      until_time: "2026-02-01", type_filter: "vzdump", status_filter: "ok"

    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_svc)
    result = handler.list(
      node: "pve1", limit: 20, since: "2026-01-01",
      until_time: "2026-02-01", type_filter: "vzdump", status_filter: "ok"
    )

    assert_equal 1, result.size
    mock_svc.verify
  end

  def test_list_returns_empty_array_when_no_tasks
    mock_svc = Minitest::Mock.new
    mock_svc.expect :list, [], [],
      node: nil, vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_svc)
    result = handler.list

    assert_empty result
    mock_svc.verify
  end

  def test_presenter_returns_task_entry_presenter
    handler = Pvectl::Commands::Get::Handlers::Tasks.new(service: mock_service([]))
    assert_instance_of Pvectl::Presenters::TaskEntry, handler.presenter
  end

  def test_handler_is_registered_for_tasks
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/tasks.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("tasks")
  end

  def test_handler_is_registered_with_task_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/tasks.rb", __FILE__)

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("task")
  end

  def test_registry_returns_tasks_handler_instance
    Pvectl::Commands::Get::ResourceRegistry.reset!
    load File.expand_path("../../../../../../lib/pvectl/commands/get/handlers/tasks.rb", __FILE__)

    handler = Pvectl::Commands::Get::ResourceRegistry.for("tasks")
    assert_instance_of Pvectl::Commands::Get::Handlers::Tasks, handler
  end

  private

  def mock_service(entries)
    svc = Object.new
    svc.define_singleton_method(:list) { |**_kwargs| entries }
    svc
  end
end
