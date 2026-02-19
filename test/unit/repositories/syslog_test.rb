# frozen_string_literal: true

require "test_helper"

class SyslogRepositoryTest < Minitest::Test
  def setup
    @mock_client = Minitest::Mock.new
    @mock_connection = Minitest::Mock.new
    @mock_connection.expect :client, @mock_client
    @repo = Pvectl::Repositories::Syslog.new(@mock_connection)
  end

  def test_list_calls_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [
      { n: 1, t: "Feb 19 14:32:01 pve1 pvedaemon[1234]: starting VM 100" }
    ], [], params: { limit: 50 }

    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/syslog"]

    result = @repo.list(node: "pve1")

    assert_equal 1, result.size
    assert_instance_of Pvectl::Models::SyslogEntry, result.first
    mock_endpoint.verify
  end

  def test_list_with_service_filter
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect :get, [], [], params: { limit: 50, service: "pvedaemon" }

    @mock_connection.expect :client, @mock_client
    @mock_client.expect :[], mock_endpoint, ["nodes/pve1/syslog"]

    @repo.list(node: "pve1", service: "pvedaemon")
    mock_endpoint.verify
  end
end
