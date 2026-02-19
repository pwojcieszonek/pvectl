# frozen_string_literal: true

require "test_helper"

class JournalRepositoryTest < Minitest::Test
  def setup
    @mock_client = Minitest::Mock.new
    @mock_connection = Minitest::Mock.new
    @mock_connection.expect :client, @mock_client
    @repo = Pvectl::Repositories::Journal.new(@mock_connection)
  end

  def test_list_calls_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [
      { n: 1, t: "Feb 19 systemd[1]: Started VM" }
    ], [], params: { lastentries: 50 }

    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/journal"]

    result = @repo.list(node: "pve1")

    assert_equal 1, result.size
    assert_instance_of Pvectl::Models::JournalEntry, result.first
    mock_endpoint.verify
  end
end
