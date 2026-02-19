# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Parsers
    class LxcNetConfigTest < Minitest::Test
      describe ".parse" do
        it "parses full LXC net config" do
          result = LxcNetConfig.parse("bridge=vmbr0,name=eth0,ip=dhcp,tag=100,firewall=1")

          assert_equal "vmbr0", result[:bridge]
          assert_equal "eth0", result[:name]
          assert_equal "dhcp", result[:ip]
          assert_equal "100", result[:tag]
          assert_equal "1", result[:firewall]
        end

        it "parses minimal config with only bridge" do
          result = LxcNetConfig.parse("bridge=vmbr0")
          assert_equal "vmbr0", result[:bridge]
        end

        it "parses static IP with gateway" do
          result = LxcNetConfig.parse("bridge=vmbr0,ip=10.0.0.5/24,gw=10.0.0.1")

          assert_equal "10.0.0.5/24", result[:ip]
          assert_equal "10.0.0.1", result[:gw]
        end

        it "parses IPv6 config" do
          result = LxcNetConfig.parse("bridge=vmbr0,ip6=auto,gw6=fe80::1")

          assert_equal "auto", result[:ip6]
          assert_equal "fe80::1", result[:gw6]
        end

        it "raises ArgumentError when bridge is missing" do
          error = assert_raises(ArgumentError) { LxcNetConfig.parse("name=eth0") }
          assert_includes error.message, "bridge"
        end

        it "raises ArgumentError when bridge is empty" do
          error = assert_raises(ArgumentError) { LxcNetConfig.parse("bridge=") }
          assert_includes error.message, "bridge"
        end

        it "raises ArgumentError for unknown key" do
          error = assert_raises(ArgumentError) { LxcNetConfig.parse("bridge=vmbr0,bad=val") }
          assert_includes error.message, "bad"
        end

        it "handles spaces around values" do
          result = LxcNetConfig.parse("bridge= vmbr0 , name=eth0")
          assert_equal "vmbr0", result[:bridge]
          assert_equal "eth0", result[:name]
        end
      end

      describe ".to_proxmox" do
        it "formats minimal config with defaults" do
          config = { bridge: "vmbr0" }
          result = LxcNetConfig.to_proxmox(config)
          assert_equal "name=eth0,bridge=vmbr0,type=veth", result
        end

        it "uses specified name and type" do
          config = { bridge: "vmbr0", name: "eth1", type: "veth" }
          result = LxcNetConfig.to_proxmox(config)
          assert_includes result, "name=eth1"
        end

        it "includes IP config" do
          config = { bridge: "vmbr0", ip: "dhcp" }
          result = LxcNetConfig.to_proxmox(config)
          assert_includes result, "ip=dhcp"
        end

        it "includes static IP with gateway" do
          config = { bridge: "vmbr0", ip: "10.0.0.5/24", gw: "10.0.0.1" }
          result = LxcNetConfig.to_proxmox(config)
          assert_includes result, "ip=10.0.0.5/24"
          assert_includes result, "gw=10.0.0.1"
        end

        it "includes VLAN tag and firewall" do
          config = { bridge: "vmbr0", tag: "100", firewall: "1" }
          result = LxcNetConfig.to_proxmox(config)
          assert_includes result, "tag=100"
          assert_includes result, "firewall=1"
        end

        it "includes rate limit" do
          config = { bridge: "vmbr0", rate: "100" }
          result = LxcNetConfig.to_proxmox(config)
          assert_includes result, "rate=100"
        end
      end
    end
  end
end
