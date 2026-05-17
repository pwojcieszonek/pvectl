# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Node#wakeonlan Tests
# =============================================================================

class RepositoriesNodeWakeonlanTest < Minitest::Test
  def build_mock_connection(expected_path:, response: nil, post_error: nil)
    mock_endpoint = Object.new
    mock_endpoint.define_singleton_method(:post) do |*args|
      raise post_error if post_error

      @received_args = args
      response
    end
    mock_endpoint.define_singleton_method(:received_args) { @received_args }

    mock_client = Object.new
    mock_client.define_singleton_method(:[]) do |path|
      raise "Unexpected path: #{path}" unless path == expected_path

      mock_endpoint
    end
    mock_client.define_singleton_method(:_endpoint) { mock_endpoint }

    mock_connection = Object.new
    mock_connection.define_singleton_method(:client) { mock_client }
    mock_connection
  end

  def test_wakeonlan_sends_post_to_correct_endpoint
    conn = build_mock_connection(
      expected_path: "nodes/pve3/wakeonlan",
      response: { data: "AA:BB:CC:DD:EE:FF" }
    )

    repo = Pvectl::Repositories::Node.new(conn)
    repo.wakeonlan("pve3")

    refute_nil conn.client._endpoint.received_args
  end

  def test_wakeonlan_returns_mac_address_string
    conn = build_mock_connection(
      expected_path: "nodes/pve3/wakeonlan",
      response: { data: "AA:BB:CC:DD:EE:FF" }
    )

    repo = Pvectl::Repositories::Node.new(conn)
    result = repo.wakeonlan("pve3")

    assert_equal "AA:BB:CC:DD:EE:FF", result
  end

  def test_wakeonlan_handles_unwrapped_response
    conn = build_mock_connection(
      expected_path: "nodes/pve1/wakeonlan",
      response: "11:22:33:44:55:66"
    )

    repo = Pvectl::Repositories::Node.new(conn)
    assert_equal "11:22:33:44:55:66", repo.wakeonlan("pve1")
  end

  def test_wakeonlan_propagates_api_errors
    conn = build_mock_connection(
      expected_path: "nodes/pve3/wakeonlan",
      post_error: StandardError.new("MAC address not configured")
    )

    repo = Pvectl::Repositories::Node.new(conn)

    error = assert_raises(StandardError) { repo.wakeonlan("pve3") }
    assert_match(/MAC address not configured/, error.message)
  end
end
