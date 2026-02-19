# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Parsers
    class NetConfigTest < Minitest::Test
      describe ".parse" do
        it "parses full net config with all keys" do
          result = NetConfig.parse("bridge=vmbr0,model=virtio,tag=100,firewall=1,mtu=1500,queues=4")

          assert_equal "vmbr0", result[:bridge]
          assert_equal "virtio", result[:model]
          assert_equal "100", result[:tag]
          assert_equal "1", result[:firewall]
          assert_equal "1500", result[:mtu]
          assert_equal "4", result[:queues]
        end

        it "parses minimal config with only bridge" do
          result = NetConfig.parse("bridge=vmbr0")
          assert_equal "vmbr0", result[:bridge]
          assert_nil result[:model]
        end

        it "raises ArgumentError when bridge is missing" do
          error = assert_raises(ArgumentError) { NetConfig.parse("model=virtio") }
          assert_includes error.message, "bridge"
        end

        it "raises ArgumentError when bridge is empty" do
          error = assert_raises(ArgumentError) { NetConfig.parse("bridge=") }
          assert_includes error.message, "bridge"
        end

        it "raises ArgumentError for unknown key" do
          error = assert_raises(ArgumentError) { NetConfig.parse("bridge=vmbr0,bad=val") }
          assert_includes error.message, "bad"
        end

        it "handles spaces around values" do
          result = NetConfig.parse("bridge= vmbr0 , model=virtio")
          assert_equal "vmbr0", result[:bridge]
          assert_equal "virtio", result[:model]
        end
      end

      describe ".to_proxmox" do
        it "formats net config with default model" do
          config = { bridge: "vmbr0" }
          result = NetConfig.to_proxmox(config)
          assert_equal "virtio,bridge=vmbr0", result
        end

        it "uses specified model" do
          config = { bridge: "vmbr0", model: "e1000" }
          result = NetConfig.to_proxmox(config)
          assert_equal "e1000,bridge=vmbr0", result
        end

        it "includes VLAN tag" do
          config = { bridge: "vmbr0", tag: "100" }
          result = NetConfig.to_proxmox(config)
          assert_includes result, "tag=100"
        end

        it "includes firewall flag" do
          config = { bridge: "vmbr0", firewall: "1" }
          result = NetConfig.to_proxmox(config)
          assert_includes result, "firewall=1"
        end
      end
    end
  end
end
