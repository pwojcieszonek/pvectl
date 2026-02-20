# frozen_string_literal: true

require "test_helper"

class ServicesTaskListingTest < Minitest::Test
  def setup
    @entry_pve1 = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve1:000A:...", node: "pve1", type: "qmstart",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_000,
      endtime: 1_708_300_005, user: "root@pam", id: "100"
    )
    @entry_pve2 = Pvectl::Models::TaskEntry.new(
      upid: "UPID:pve2:000B:...", node: "pve2", type: "qmstop",
      status: "stopped", exitstatus: "OK", starttime: 1_708_300_010,
      endtime: 1_708_300_012, user: "root@pam", id: "100"
    )
    @node1 = Pvectl::Models::Node.new(name: "pve1", status: "online")
    @node2 = Pvectl::Models::Node.new(name: "pve2", status: "online")
  end

  def test_list_single_node
    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [@entry_pve1], [],
      node: "pve1", vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    service = Pvectl::Services::TaskListing.new(
      task_list_repository: mock_task_list_repo,
      node_repository: Object.new
    )

    result = service.list(node: "pve1")
    assert_equal 1, result.size
    assert_equal "qmstart", result.first.type
    mock_task_list_repo.verify
  end

  def test_list_all_nodes_when_node_is_nil
    mock_node_repo = Minitest::Mock.new
    mock_node_repo.expect :list, [@node1, @node2]

    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [@entry_pve1], [],
      node: "pve1", vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil
    mock_task_list_repo.expect :list, [@entry_pve2], [],
      node: "pve2", vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    service = Pvectl::Services::TaskListing.new(
      task_list_repository: mock_task_list_repo,
      node_repository: mock_node_repo
    )

    result = service.list
    assert_equal 2, result.size
    assert_equal "qmstop", result.first.type, "sorted by starttime descending"
    assert_equal "qmstart", result.last.type
    mock_node_repo.verify
    mock_task_list_repo.verify
  end

  def test_list_all_nodes_respects_limit
    mock_node_repo = Minitest::Mock.new
    mock_node_repo.expect :list, [@node1, @node2]

    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [@entry_pve1], [],
      node: "pve1", vmid: nil, limit: 1, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil
    mock_task_list_repo.expect :list, [@entry_pve2], [],
      node: "pve2", vmid: nil, limit: 1, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    service = Pvectl::Services::TaskListing.new(
      task_list_repository: mock_task_list_repo,
      node_repository: mock_node_repo
    )

    result = service.list(limit: 1)
    assert_equal 1, result.size
    assert_equal "qmstop", result.first.type, "returns newest entry"
  end

  def test_list_passes_filters_to_repository
    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [@entry_pve1], [],
      node: "pve1", vmid: 100, limit: 20, since: "2026-01-01",
      until_time: "2026-02-01", type_filter: "vzdump", status_filter: "ok"

    service = Pvectl::Services::TaskListing.new(
      task_list_repository: mock_task_list_repo,
      node_repository: Object.new
    )

    result = service.list(
      node: "pve1", vmid: 100, limit: 20, since: "2026-01-01",
      until_time: "2026-02-01", type_filter: "vzdump", status_filter: "ok"
    )
    assert_equal 1, result.size
    mock_task_list_repo.verify
  end

  def test_list_returns_empty_array_when_no_tasks
    mock_task_list_repo = Minitest::Mock.new
    mock_task_list_repo.expect :list, [], [],
      node: "pve1", vmid: nil, limit: 50, since: nil,
      until_time: nil, type_filter: nil, status_filter: nil

    service = Pvectl::Services::TaskListing.new(
      task_list_repository: mock_task_list_repo,
      node_repository: Object.new
    )

    result = service.list(node: "pve1")
    assert_empty result
    mock_task_list_repo.verify
  end
end
