# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Parsers
    class CloudInitConfigTest < Minitest::Test
      describe ".parse" do
        it "parses full cloud-init config" do
          result = CloudInitConfig.parse("user=admin,password=secret,ip=dhcp,nameserver=8.8.8.8,searchdomain=local")

          assert_equal "admin", result[:user]
          assert_equal "secret", result[:password]
          assert_equal "dhcp", result[:ip]
          assert_equal "8.8.8.8", result[:nameserver]
          assert_equal "local", result[:searchdomain]
        end

        it "parses sshkeys" do
          result = CloudInitConfig.parse("user=admin,sshkeys=ssh-rsa%20AAAA...")

          assert_equal "admin", result[:user]
          assert_equal "ssh-rsa%20AAAA...", result[:sshkeys]
        end

        it "allows single key config" do
          result = CloudInitConfig.parse("user=admin")

          assert_equal "admin", result[:user]
        end

        it "raises ArgumentError for unknown key" do
          error = assert_raises(ArgumentError) { CloudInitConfig.parse("user=admin,bad=val") }
          assert_includes error.message, "bad"
        end

        it "handles spaces around values" do
          result = CloudInitConfig.parse("user= admin , ip=dhcp")

          assert_equal "admin", result[:user]
          assert_equal "dhcp", result[:ip]
        end

        it "parses static ip with gateway" do
          result = CloudInitConfig.parse("user=admin,ip=10.0.0.5/24,gw=10.0.0.1")

          assert_equal "admin", result[:user]
          assert_equal "10.0.0.5/24", result[:ip]
          assert_equal "10.0.0.1", result[:gw]
        end
      end

      describe ".to_proxmox_params" do
        it "maps user to ciuser" do
          result = CloudInitConfig.to_proxmox_params({ user: "admin" })
          assert_equal "admin", result[:ciuser]
        end

        it "maps password to cipassword" do
          result = CloudInitConfig.to_proxmox_params({ password: "secret" })
          assert_equal "secret", result[:cipassword]
        end

        it "maps sshkeys directly" do
          result = CloudInitConfig.to_proxmox_params({ sshkeys: "ssh-rsa%20AAAA..." })
          assert_equal "ssh-rsa%20AAAA...", result[:sshkeys]
        end

        it "maps ip=dhcp to ipconfig0" do
          result = CloudInitConfig.to_proxmox_params({ ip: "dhcp" })
          assert_equal "ip=dhcp", result[:ipconfig0]
        end

        it "maps static ip to ipconfig0" do
          result = CloudInitConfig.to_proxmox_params({ ip: "10.0.0.5/24" })
          assert_equal "ip=10.0.0.5/24", result[:ipconfig0]
        end

        it "maps static ip with gateway to ipconfig0" do
          result = CloudInitConfig.to_proxmox_params({ ip: "10.0.0.5/24", gw: "10.0.0.1" })
          assert_equal "ip=10.0.0.5/24,gw=10.0.0.1", result[:ipconfig0]
        end

        it "maps nameserver directly" do
          result = CloudInitConfig.to_proxmox_params({ nameserver: "8.8.8.8" })
          assert_equal "8.8.8.8", result[:nameserver]
        end

        it "maps searchdomain directly" do
          result = CloudInitConfig.to_proxmox_params({ searchdomain: "local" })
          assert_equal "local", result[:searchdomain]
        end

        it "returns empty hash for empty config" do
          result = CloudInitConfig.to_proxmox_params({})
          assert_equal({}, result)
        end

        it "maps all keys together" do
          config = { user: "admin", password: "secret", sshkeys: "key", ip: "dhcp", nameserver: "8.8.8.8", searchdomain: "local" }
          result = CloudInitConfig.to_proxmox_params(config)

          assert_equal "admin", result[:ciuser]
          assert_equal "secret", result[:cipassword]
          assert_equal "key", result[:sshkeys]
          assert_equal "ip=dhcp", result[:ipconfig0]
          assert_equal "8.8.8.8", result[:nameserver]
          assert_equal "local", result[:searchdomain]
        end
      end
    end
  end
end
