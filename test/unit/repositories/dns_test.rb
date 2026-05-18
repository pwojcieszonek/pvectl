# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class DnsTest < Minitest::Test
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
        mock_connection.define_singleton_method(:endpoint) { mock_endpoint }
        mock_connection
      end

      def test_fetch_returns_dns_config_with_all_fields
        response = { data: { search: "example.com", dns1: "8.8.8.8", dns2: "1.1.1.1", dns3: "9.9.9.9" } }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/dns",
          method: :get,
          response: response
        )
        repo = Dns.new(conn)
        dns = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::DnsConfig, dns
        assert_equal "pve1", dns.node
        assert_equal "example.com", dns.search
        assert_equal "8.8.8.8", dns.dns1
        assert_equal "1.1.1.1", dns.dns2
        assert_equal "9.9.9.9", dns.dns3
      end

      def test_fetch_handles_missing_optional_fields
        response = { data: { search: "example.com", dns1: "8.8.8.8" } }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/dns",
          method: :get,
          response: response
        )
        repo = Dns.new(conn)
        dns = repo.fetch("pve1")

        assert_equal "8.8.8.8", dns.dns1
        assert_nil dns.dns2
        assert_nil dns.dns3
      end

      def test_fetch_handles_empty_response
        response = { data: {} }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/dns",
          method: :get,
          response: response
        )
        repo = Dns.new(conn)
        dns = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::DnsConfig, dns
        assert_equal "pve1", dns.node
        assert_nil dns.search
        assert_nil dns.dns1
      end

      def test_update_sends_put_with_provided_attrs
        conn = build_mock_connection(
          expected_path: "nodes/pve1/dns",
          method: :put,
          response: nil
        )
        repo = Dns.new(conn)
        repo.update("pve1", { search: "new.example.com", dns1: "8.8.4.4" })

        params = conn.endpoint.received_params
        assert_equal "new.example.com", params[:search]
        assert_equal "8.8.4.4", params[:dns1]
      end

      def test_update_passes_only_given_keys
        conn = build_mock_connection(
          expected_path: "nodes/pve1/dns",
          method: :put,
          response: nil
        )
        repo = Dns.new(conn)
        repo.update("pve1", { search: "example.com" })

        params = conn.endpoint.received_params
        assert_equal "example.com", params[:search]
        refute params.key?(:dns1)
      end
    end
  end
end
