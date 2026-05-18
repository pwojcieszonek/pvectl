# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    # =============================================================================
    # Repositories::TimeConfig Tests
    # =============================================================================
    class TimeConfigTest < Minitest::Test
      def build_mock_connection(expected_path:, method:, response: nil)
        mock_endpoint = Object.new
        case method
        when :get
          mock_endpoint.define_singleton_method(:get) { |**_kwargs| response }
        when :put
          mock_endpoint.define_singleton_method(:put) do |p|
            @received_params = p
            response
          end
          mock_endpoint.define_singleton_method(:received_params) { @received_params }
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          raise "Unexpected path: #{path}" unless path == expected_path

          mock_endpoint
        end
        # Expose endpoint for inspection (for PUT params)
        mock_client.define_singleton_method(:_endpoint) { mock_endpoint }

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }
        mock_connection
      end

      # ---------------------------
      # Class existence
      # ---------------------------

      def test_class_exists
        assert_kind_of Class, Pvectl::Repositories::TimeConfig
      end

      def test_inherits_from_base
        assert Pvectl::Repositories::TimeConfig < Pvectl::Repositories::Base
      end

      # ---------------------------
      # fetch
      # ---------------------------

      def test_fetch_returns_time_config_model
        api_data = { time: 1_715_000_000, localtime: 1_715_007_200, timezone: "Europe/Warsaw" }
        conn = build_mock_connection(
          expected_path: "nodes/pve1/time",
          method: :get,
          response: { data: api_data }
        )

        repo = Pvectl::Repositories::TimeConfig.new(conn)
        result = repo.fetch("pve1")

        assert_kind_of Pvectl::Models::TimeConfig, result
        assert_equal "pve1", result.node_name
        assert_equal 1_715_000_000, result.time
        assert_equal 1_715_007_200, result.localtime
        assert_equal "Europe/Warsaw", result.timezone
      end

      def test_fetch_handles_unwrapped_response
        api_data = { time: 1_715_000_000, localtime: 1_715_007_200, timezone: "UTC" }
        conn = build_mock_connection(
          expected_path: "nodes/pve2/time",
          method: :get,
          response: api_data
        )

        repo = Pvectl::Repositories::TimeConfig.new(conn)
        result = repo.fetch("pve2")

        assert_equal "pve2", result.node_name
        assert_equal "UTC", result.timezone
      end

      # ---------------------------
      # set_timezone
      # ---------------------------

      def test_set_timezone_sends_put_with_timezone
        conn = build_mock_connection(
          expected_path: "nodes/pve1/time",
          method: :put,
          response: nil
        )

        repo = Pvectl::Repositories::TimeConfig.new(conn)
        repo.set_timezone("pve1", "Europe/Warsaw")

        received = conn.client._endpoint.received_params
        assert_equal "Europe/Warsaw", received[:timezone]
      end

      def test_set_timezone_returns_nil_on_success
        conn = build_mock_connection(
          expected_path: "nodes/pve1/time",
          method: :put,
          response: nil
        )

        repo = Pvectl::Repositories::TimeConfig.new(conn)
        assert_nil repo.set_timezone("pve1", "UTC")
      end
    end
  end
end
