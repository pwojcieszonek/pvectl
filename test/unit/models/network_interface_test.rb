# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class NetworkInterfaceTest < Minitest::Test
      def test_initializes_with_attributes
        iface = NetworkInterface.new(
          iface: "vmbr0",
          type: "bridge",
          address: "192.168.1.10/24",
          gateway: "192.168.1.1"
        )

        assert_equal "vmbr0", iface.iface
        assert_equal "bridge", iface.type
        assert_equal "192.168.1.10/24", iface.address
        assert_equal "192.168.1.1", iface.gateway
      end

      def test_active_predicate
        active = NetworkInterface.new(active: 1)
        inactive = NetworkInterface.new(active: 0)

        assert active.active?
        refute inactive.active?
      end

      def test_has_gateway_predicate
        with_gateway = NetworkInterface.new(gateway: "192.168.1.1")
        without_gateway = NetworkInterface.new(gateway: nil)
        empty_gateway = NetworkInterface.new(gateway: "")

        assert with_gateway.has_gateway?
        refute without_gateway.has_gateway?
        refute empty_gateway.has_gateway?
      end

      def test_ip_without_cidr
        iface = NetworkInterface.new(address: "192.168.1.10/24")
        assert_equal "192.168.1.10", iface.ip_without_cidr

        iface_no_cidr = NetworkInterface.new(address: "192.168.1.10")
        assert_equal "192.168.1.10", iface_no_cidr.ip_without_cidr

        iface_nil = NetworkInterface.new(address: nil)
        assert_nil iface_nil.ip_without_cidr
      end

      def test_handles_string_keys
        iface = NetworkInterface.new("iface" => "eth0", "type" => "eth")
        assert_equal "eth0", iface.iface
        assert_equal "eth", iface.type
      end
    end
  end
end
