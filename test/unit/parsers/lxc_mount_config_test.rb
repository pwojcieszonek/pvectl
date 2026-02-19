# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Parsers
    class LxcMountConfigTest < Minitest::Test
      describe ".parse" do
        it "parses rootfs config with storage and size" do
          result = LxcMountConfig.parse("storage=local-lvm,size=8G")

          assert_equal "local-lvm", result[:storage]
          assert_equal "8G", result[:size]
        end

        it "parses mountpoint config with mp path" do
          result = LxcMountConfig.parse("mp=/mnt/data,storage=local-lvm,size=32G")

          assert_equal "/mnt/data", result[:mp]
          assert_equal "local-lvm", result[:storage]
          assert_equal "32G", result[:size]
        end

        it "parses config with optional flags" do
          result = LxcMountConfig.parse("storage=local-lvm,size=8G,backup=1,quota=1")

          assert_equal "local-lvm", result[:storage]
          assert_equal "1", result[:backup]
          assert_equal "1", result[:quota]
        end

        it "raises ArgumentError for unknown key" do
          error = assert_raises(ArgumentError) { LxcMountConfig.parse("storage=local-lvm,size=8G,bad=val") }
          assert_includes error.message, "bad"
        end

        it "raises ArgumentError when storage is missing" do
          error = assert_raises(ArgumentError) { LxcMountConfig.parse("size=8G") }
          assert_includes error.message, "storage"
        end

        it "raises ArgumentError when size is missing" do
          error = assert_raises(ArgumentError) { LxcMountConfig.parse("storage=local-lvm") }
          assert_includes error.message, "size"
        end

        it "raises ArgumentError when storage is empty" do
          error = assert_raises(ArgumentError) { LxcMountConfig.parse("storage=,size=8G") }
          assert_includes error.message, "storage"
        end

        it "handles spaces around values" do
          result = LxcMountConfig.parse("storage= local-lvm , size=8G")
          assert_equal "local-lvm", result[:storage]
          assert_equal "8G", result[:size]
        end
      end

      describe ".to_proxmox" do
        it "formats rootfs config" do
          config = { storage: "local-lvm", size: "8G" }
          result = LxcMountConfig.to_proxmox(config)
          assert_equal "local-lvm:8", result
        end

        it "formats mountpoint config with mp path" do
          config = { storage: "local-lvm", size: "32G", mp: "/mnt/data" }
          result = LxcMountConfig.to_proxmox(config)
          assert_equal "local-lvm:32,mp=/mnt/data", result
        end

        it "includes optional flags" do
          config = { storage: "local-lvm", size: "8G", backup: "1", quota: "1" }
          result = LxcMountConfig.to_proxmox(config)
          assert_includes result, "local-lvm:8"
          assert_includes result, "backup=1"
          assert_includes result, "quota=1"
        end

        it "strips size suffix" do
          config = { storage: "ceph", size: "100G" }
          result = LxcMountConfig.to_proxmox(config)
          assert_equal "ceph:100", result
        end
      end
    end
  end
end
