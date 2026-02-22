# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class NodeConfigTest < Minitest::Test
      def build_mock_connection(expected_path:, method:, response:)
        mock_endpoint = Object.new
        if method == :get
          mock_endpoint.define_singleton_method(:get) { |**_kwargs| response }
        elsif method == :put
          mock_endpoint.define_singleton_method(:put) { |p| @received_params = p }
          mock_endpoint.define_singleton_method(:received_params) { @received_params }
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          raise "Unexpected path: #{path}" unless path == expected_path
          mock_endpoint
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }
        mock_connection
      end

      def test_fetch_config_returns_hash
        config_data = { description: "test node", digest: "abc123", wakeonlan: "00:11:22:33:44:55" }
        response = { "data" => config_data }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/config",
          method: :get,
          response: response
        )
        repo = Node.new(conn)
        result = repo.fetch_config("pve1")
        assert_kind_of Hash, result
      end

      def test_fetch_config_returns_empty_on_error
        mock_endpoint = Object.new
        mock_endpoint.define_singleton_method(:get) { |**_kwargs| raise StandardError, "connection refused" }

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) { |_path| mock_endpoint }

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        repo = Node.new(mock_connection)
        result = repo.fetch_config("bad-node")
        assert_equal({}, result)
      end

      def test_update_sends_put
        conn = build_mock_connection(
          expected_path: "nodes/pve1/config",
          method: :put,
          response: nil
        )
        repo = Node.new(conn)
        # Should not raise
        repo.update("pve1", { description: "updated" })
      end
    end
  end
end
