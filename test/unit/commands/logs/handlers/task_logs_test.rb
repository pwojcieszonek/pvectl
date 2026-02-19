# frozen_string_literal: true

require "test_helper"

class LogsHandlersTaskLogsTest < Minitest::Test
  def setup
    @entry = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:...", node: "pve1", type: "qmstart",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_000,
      endtime: 1_708_300_005, user: "root@pam", id: "100"
    )
  end

  def test_list_resolves_node_and_fetches_tasks
    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [@entry], [], node: "pve1", vmid: 100,
      limit: 50, since: nil, until_time: nil, type_filter: nil, status_filter: nil

    mock_vm_repo = Minitest::Mock.new
    mock_vm_repo.expect :get, Pvectl::Models::Vm.new(vmid: 100, node: "pve1"), [100]

    handler = Pvectl::Commands::Logs::Handlers::TaskLogs.new(
      task_list_repository: mock_task_list_repo,
      vm_repository: mock_vm_repo
    )

    result = handler.list(vmid: 100, resource_type: "vm")
    assert_equal 1, result.size
    assert_equal "qmstart", result.first.type
    mock_task_list_repo.verify
    mock_vm_repo.verify
  end

  def test_list_raises_not_found_when_vm_missing
    mock_vm_repo = Minitest::Mock.new
    mock_vm_repo.expect :get, nil, [999]

    handler = Pvectl::Commands::Logs::Handlers::TaskLogs.new(
      task_list_repository: Object.new,
      vm_repository: mock_vm_repo
    )

    assert_raises(Pvectl::ResourceNotFoundError) do
      handler.list(vmid: 999, resource_type: "vm")
    end
  end

  def test_list_all_nodes_iterates_cluster_and_sorts_by_starttime
    entry_pve1 = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:...", node: "pve1", type: "qmstart",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_000
    )
    entry_pve2 = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve2:...", node: "pve2", type: "qmstop",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_010
    )

    node1 = Pvectl::Models::Node.new(name: "pve1", status: "online")
    node2 = Pvectl::Models::Node.new(name: "pve2", status: "online")

    mock_node_repo = Minitest::Mock.new
    mock_node_repo.expect :list, [node1, node2]

    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [entry_pve1], [], node: "pve1", vmid: 100,
      limit: 50, since: nil, until_time: nil, type_filter: nil, status_filter: nil
    mock_task_list_repo.expect :list, [entry_pve2], [], node: "pve2", vmid: 100,
      limit: 50, since: nil, until_time: nil, type_filter: nil, status_filter: nil

    handler = Pvectl::Commands::Logs::Handlers::TaskLogs.new(
      task_list_repository: mock_task_list_repo,
      node_repository: mock_node_repo
    )

    result = handler.list(vmid: 100, resource_type: "vm", all_nodes: true)

    assert_equal 2, result.size
    assert_equal "qmstop", result.first.type, "should be sorted by starttime descending"
    assert_equal "qmstart", result.last.type
    mock_node_repo.verify
    mock_task_list_repo.verify
  end

  def test_presenter_returns_task_entry
    handler = Pvectl::Commands::Logs::Handlers::TaskLogs.new(
      task_list_repository: Object.new, vm_repository: Object.new
    )
    assert_instance_of Pvectl::Presenters::TaskEntry, handler.presenter
  end
end
