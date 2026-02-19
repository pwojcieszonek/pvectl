# frozen_string_literal: true

require "test_helper"
require "cgi"

class TaskLogRepositoryTest < Minitest::Test
  def setup
    @mock_client = Minitest::Mock.new
    @mock_connection = Minitest::Mock.new
    @mock_connection.expect :client, @mock_client
    @repo = Pvectl::Repositories::TaskLog.new(@mock_connection)
  end

  def test_list_calls_correct_endpoint
    upid = "UPID:pve1:000ABC:001234:65B63BF0:qmstart:100:root@pam:"
    escaped = CGI.escape(upid)

    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [
      { n: 1, t: "starting VM 100 on 'pve1'" },
      { n: 2, t: "TASK OK" }
    ], [], params: { start: 0, limit: 512 }

    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/tasks/#{escaped}/log"]

    result = @repo.list(upid: upid)

    assert_equal 2, result.size
    assert_instance_of Pvectl::Models::TaskLogLine, result.first
    assert_equal "starting VM 100 on 'pve1'", result.first.t
    mock_endpoint.verify
  end
end
