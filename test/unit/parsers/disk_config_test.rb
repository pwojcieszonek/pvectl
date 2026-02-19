# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Parsers
    class DiskConfigTest < Minitest::Test
      describe ".parse" do
        it "parses full disk config with all keys" do
          result = DiskConfig.parse("storage=local-lvm,size=32G,format=qcow2,cache=writeback,discard=on,ssd=1,iothread=1,backup=1")

          assert_equal "local-lvm", result[:storage]
          assert_equal "32G", result[:size]
          assert_equal "qcow2", result[:format]
          assert_equal "writeback", result[:cache]
          assert_equal "on", result[:discard]
          assert_equal "1", result[:ssd]
          assert_equal "1", result[:iothread]
          assert_equal "1", result[:backup]
        end

        it "parses minimal config with only required keys" do
          result = DiskConfig.parse("storage=local-lvm,size=32G")

          assert_equal "local-lvm", result[:storage]
          assert_equal "32G", result[:size]
          assert_nil result[:format]
        end

        it "raises ArgumentError when storage is missing" do
          error = assert_raises(ArgumentError) { DiskConfig.parse("size=32G") }
          assert_includes error.message, "storage"
        end

        it "raises ArgumentError when size is missing" do
          error = assert_raises(ArgumentError) { DiskConfig.parse("storage=local-lvm") }
          assert_includes error.message, "size"
        end

        it "raises ArgumentError for unknown key" do
          error = assert_raises(ArgumentError) { DiskConfig.parse("storage=local-lvm,size=32G,unknown=val") }
          assert_includes error.message, "unknown"
        end

        it "raises ArgumentError when required key has empty value" do
          error = assert_raises(ArgumentError) { DiskConfig.parse("storage=,size=32G") }
          assert_includes error.message, "storage"
        end

        it "handles spaces around values" do
          result = DiskConfig.parse("storage= local-lvm , size=32G")

          assert_equal "local-lvm", result[:storage]
          assert_equal "32G", result[:size]
        end
      end

      describe ".to_proxmox" do
        it "formats disk config as Proxmox API string" do
          config = { storage: "local-lvm", size: "32G" }
          result = DiskConfig.to_proxmox(config)

          assert_equal "local-lvm:32,format=raw", result
        end

        it "formats disk config with format" do
          config = { storage: "local-lvm", size: "32G", format: "qcow2" }
          result = DiskConfig.to_proxmox(config)

          assert_equal "local-lvm:32,format=qcow2", result
        end

        it "includes optional flags" do
          config = { storage: "local-lvm", size: "32G", cache: "writeback", discard: "on", ssd: "1", iothread: "1" }
          result = DiskConfig.to_proxmox(config)

          assert_includes result, "cache=writeback"
          assert_includes result, "discard=on"
          assert_includes result, "ssd=1"
          assert_includes result, "iothread=1"
        end

        it "extracts numeric size from size string with G suffix" do
          config = { storage: "ceph", size: "100G" }
          result = DiskConfig.to_proxmox(config)

          assert_equal "ceph:100,format=raw", result
        end
      end
    end
  end
end
