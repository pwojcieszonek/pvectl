# frozen_string_literal: true

require "test_helper"

class RepositoriesVmTermproxyTest < Minitest::Test
  def test_termproxy_posts_to_correct_endpoint
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, { port: 5900, ticket: "PVEVNC:abc123", user: "root@pam" }, [{}])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/termproxy"])

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    result = repo.termproxy(100, "pve1")

    assert_equal 5900, result[:port]
    assert_equal "PVEVNC:abc123", result[:ticket]
    assert_equal "root@pam", result[:user]
    mock_endpoint.verify
    mock_client.verify
  end

  def test_termproxy_returns_hash_with_required_keys
    mock_endpoint = Object.new
    mock_endpoint.define_singleton_method(:post) { |_| { port: 5901, ticket: "PVEVNC:xyz", user: "admin@pve" } }

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) { |_| mock_endpoint }

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }

    repo = Pvectl::Repositories::Vm.new(mock_connection)
    result = repo.termproxy(200, "pve2")

    assert_kind_of Hash, result
    assert result.key?(:port)
    assert result.key?(:ticket)
    assert result.key?(:user)
  end
end
