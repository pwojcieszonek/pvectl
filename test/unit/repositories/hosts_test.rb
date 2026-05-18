# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class HostsTest < Minitest::Test
      def build_mock_connection(expected_path:, method:, response: nil)
        mock_endpoint = Object.new
        if method == :get
          mock_endpoint.define_singleton_method(:get) { |**_kwargs| response }
        elsif method == :post
          mock_endpoint.define_singleton_method(:post) { |p| @received_params = p }
          mock_endpoint.define_singleton_method(:received_params) { @received_params }
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          raise "Unexpected path: #{path}" unless path == expected_path
          mock_endpoint
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }
        mock_connection.define_singleton_method(:endpoint) { mock_endpoint }
        mock_connection
      end

      def test_fetch_returns_hosts_file_with_data_and_digest
        response = {
          data: {
            data: "127.0.0.1 localhost\n192.168.1.1 pve1.example.com pve1 pvelocalhost\n",
            digest: "abc123def456"
          }
        }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :get,
          response: response
        )
        repo = Hosts.new(conn)
        hosts = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::HostsFile, hosts
        assert_equal "pve1", hosts.node
        assert_match(/127\.0\.0\.1 localhost/, hosts.data)
        assert_equal "abc123def456", hosts.digest
        assert_equal 2, hosts.line_count
      end

      def test_fetch_handles_missing_digest
        response = { data: { data: "127.0.0.1 localhost\n" } }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :get,
          response: response
        )
        repo = Hosts.new(conn)
        hosts = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::HostsFile, hosts
        assert_nil hosts.digest
        assert_equal "127.0.0.1 localhost\n", hosts.data
      end

      def test_fetch_handles_empty_response
        response = { data: {} }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :get,
          response: response
        )
        repo = Hosts.new(conn)
        hosts = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::HostsFile, hosts
        assert_equal "pve1", hosts.node
        assert_equal "", hosts.data
        assert_nil hosts.digest
      end

      def test_update_sends_post_with_data_and_digest
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :post
        )
        repo = Hosts.new(conn)
        repo.update("pve1", "127.0.0.1 localhost\n", "abc123")

        params = conn.endpoint.received_params
        assert_equal "127.0.0.1 localhost\n", params[:data]
        assert_equal "abc123", params[:digest]
      end

      def test_update_omits_digest_when_nil
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :post
        )
        repo = Hosts.new(conn)
        repo.update("pve1", "127.0.0.1 localhost\n", nil)

        params = conn.endpoint.received_params
        assert_equal "127.0.0.1 localhost\n", params[:data]
        refute params.key?(:digest)
      end

      def test_update_omits_digest_when_empty
        conn = build_mock_connection(
          expected_path: "nodes/pve1/hosts",
          method: :post
        )
        repo = Hosts.new(conn)
        repo.update("pve1", "data", "")

        params = conn.endpoint.received_params
        refute params.key?(:digest)
      end
    end
  end
end
