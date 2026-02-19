# frozen_string_literal: true

require "test_helper"

class TaskListRepositoryTest < Minitest::Test
  def setup
    @mock_client = Minitest::Mock.new
    @mock_connection = Minitest::Mock.new
    @mock_connection.expect :client, @mock_client
    @repo = Pvectl::Repositories::TaskList.new(@mock_connection)
  end

  def test_list_calls_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [
      { upid: "UPID:pve1:...", node: "pve1", type: "qmstart", status: "stopped",
        exitstatus: "OK", starttime: 1_708_300_000, endtime: 1_708_300_005,
        user: "root@pam", id: "100" }
    ], [], params: { limit: 50, source: "all" }

    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/tasks"]

    result = @repo.list(node: "pve1")

    assert_equal 1, result.size
    assert_instance_of Pvectl::Models::TaskEntry, result.first
    assert_equal "qmstart", result.first.type
    mock_endpoint.verify
  end

  def test_list_with_vmid_filter
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [], [], params: { limit: 50, source: "all", vmid: 100 }

    @mock_connection.expect :client, @mock_client
    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/tasks"]

    @repo.list(node: "pve1", vmid: 100)
    mock_endpoint.verify
  end

  def test_list_with_all_filters
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [], [], params: {
      limit: 10, source: "all", vmid: 100,
      since: 1_708_000_000, until: 1_709_000_000,
      typefilter: "qmstart", statusfilter: "failed"
    }

    @mock_connection.expect :client, @mock_client
    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/tasks"]

    @repo.list(node: "pve1", vmid: 100, limit: 10,
               since: 1_708_000_000, until_time: 1_709_000_000,
               type_filter: "qmstart", status_filter: "failed")
    mock_endpoint.verify
  end
end
