# frozen_string_literal: true

require "test_helper"

class RepositoriesContainerTermproxyTest < Minitest::Test
  def test_termproxy_posts_to_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, { port: 5900, ticket: "PVEVNC:abc123", user: "root@pam" }, [{}])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc/200/termproxy"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Container.new(mock_connection)
    result = repo.termproxy(200, "pve1")

    assert_equal 5900, result[:port]
    assert_equal "PVEVNC:abc123", result[:ticket]
    assert_equal "root@pam", result[:user]
    mock_endpoint.verify
    mock_client.verify
  end
end
