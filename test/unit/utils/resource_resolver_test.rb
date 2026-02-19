# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Utils
    class ResourceResolverTest < Minitest::Test
      def setup
        @api_response = [
          { vmid: 100, node: "pve1", type: "qemu", name: "web-server" },
          { vmid: 101, node: "pve2", type: "lxc", name: "cache" }
        ]
      end

      def test_resolve_returns_vm_info
        resolver = create_resolver(@api_response)

        result = resolver.resolve(100)

        assert_equal 100, result[:vmid]
        assert_equal "pve1", result[:node]
        assert_equal :qemu, result[:type]
        assert_equal "web-server", result[:name]
      end

      def test_resolve_returns_container_info
        resolver = create_resolver(@api_response)

        result = resolver.resolve(101)

        assert_equal 101, result[:vmid]
        assert_equal "pve2", result[:node]
        assert_equal :lxc, result[:type]
        assert_equal "cache", result[:name]
      end

      def test_resolve_returns_nil_for_unknown_vmid
        resolver = create_resolver(@api_response)

        result = resolver.resolve(999)

        assert_nil result
      end

      def test_resolve_multiple_returns_array
        resolver = create_resolver(@api_response)

        results = resolver.resolve_multiple([100, 101])

        assert_equal 2, results.length
        assert_equal 100, results[0][:vmid]
        assert_equal 101, results[1][:vmid]
      end

      def test_resolve_multiple_skips_unknown
        resolver = create_resolver(@api_response)

        results = resolver.resolve_multiple([100, 999])

        assert_equal 1, results.length
        assert_equal 100, results[0][:vmid]
      end

      def test_caches_resources
        call_count = 0
        resolver = create_resolver_with_counter(@api_response) { call_count += 1 }

        # Call twice - should only hit API once
        resolver.resolve(100)
        resolver.resolve(100)

        assert_equal 1, call_count
      end

      def test_resolve_accepts_string_vmid
        resolver = create_resolver(@api_response)

        result = resolver.resolve("100")

        assert_equal 100, result[:vmid]
      end

      def test_resolve_multiple_accepts_string_vmids
        resolver = create_resolver(@api_response)

        results = resolver.resolve_multiple(["100", "101"])

        assert_equal 2, results.length
      end

      private

      def create_resolver(api_response)
        mock_resource = Object.new
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          api_response
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |_path|
          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) do
          mock_client
        end

        ResourceResolver.new(mock_connection)
      end

      def create_resolver_with_counter(api_response, &block)
        mock_resource = Object.new
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          block.call
          api_response
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |_path|
          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) do
          mock_client
        end

        ResourceResolver.new(mock_connection)
      end
    end
  end
end
