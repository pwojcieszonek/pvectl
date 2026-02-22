# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class ResizeVolumeTest < Minitest::Test
      # --- .parse_size ---

      describe ".parse_size" do
        describe "relative sizes" do
          it "parses relative size with G suffix" do
            parsed = ResizeVolume.parse_size("+10G")

            assert parsed.relative?
            assert_equal "10G", parsed.value
            assert_equal "+10G", parsed.raw
          end

          it "parses relative size with M suffix" do
            parsed = ResizeVolume.parse_size("+512M")

            assert parsed.relative?
            assert_equal "512M", parsed.value
            assert_equal "+512M", parsed.raw
          end

          it "parses relative size with T suffix" do
            parsed = ResizeVolume.parse_size("+1T")

            assert parsed.relative?
            assert_equal "1T", parsed.value
            assert_equal "+1T", parsed.raw
          end

          it "parses relative size with K suffix" do
            parsed = ResizeVolume.parse_size("+100K")

            assert parsed.relative?
            assert_equal "100K", parsed.value
            assert_equal "+100K", parsed.raw
          end
        end

        describe "absolute sizes" do
          it "parses absolute size with G suffix" do
            parsed = ResizeVolume.parse_size("50G")

            refute parsed.relative?
            assert_equal "50G", parsed.value
            assert_equal "50G", parsed.raw
          end

          it "parses absolute size with M suffix" do
            parsed = ResizeVolume.parse_size("1024M")

            refute parsed.relative?
            assert_equal "1024M", parsed.value
            assert_equal "1024M", parsed.raw
          end

          it "parses absolute size with T suffix" do
            parsed = ResizeVolume.parse_size("2T")

            refute parsed.relative?
            assert_equal "2T", parsed.value
            assert_equal "2T", parsed.raw
          end
        end

        describe "decimal values" do
          it "parses decimal size" do
            parsed = ResizeVolume.parse_size("1.5T")

            refute parsed.relative?
            assert_equal "1.5T", parsed.value
            assert_equal "1.5T", parsed.raw
          end

          it "parses relative decimal size" do
            parsed = ResizeVolume.parse_size("+0.5G")

            assert parsed.relative?
            assert_equal "0.5G", parsed.value
            assert_equal "+0.5G", parsed.raw
          end
        end

        describe "no suffix" do
          it "parses number without suffix" do
            parsed = ResizeVolume.parse_size("100")

            refute parsed.relative?
            assert_equal "100", parsed.value
            assert_equal "100", parsed.raw
          end

          it "parses relative number without suffix" do
            parsed = ResizeVolume.parse_size("+50")

            assert parsed.relative?
            assert_equal "50", parsed.value
            assert_equal "+50", parsed.raw
          end
        end

        describe "case insensitivity" do
          it "uppercases lowercase suffix" do
            parsed = ResizeVolume.parse_size("10g")

            assert_equal "10G", parsed.value
            assert_equal "10G", parsed.raw
          end
        end

        describe "invalid formats" do
          it "raises on invalid format" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size("abc") }
          end

          it "raises on empty string" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size("") }
          end

          it "raises on nil" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size(nil) }
          end

          it "raises on negative value (minus prefix)" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size("-10G") }
          end

          it "raises on zero value" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size("0G") }
          end

          it "raises on invalid suffix" do
            assert_raises(ArgumentError) { ResizeVolume.parse_size("10X") }
          end
        end
      end

      # --- #preflight ---

      describe "#preflight" do
        def build_mock_repo(config)
          repo = Object.new
          repo.define_singleton_method(:fetch_config) do |_node, _id|
            config
          end
          repo
        end

        describe "relative resize" do
          it "calculates new size from current + increment" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=32G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("+10G")

            result = service.preflight(100, "scsi0", parsed, node: "pve1")

            assert_equal "scsi0", result[:disk]
            assert_equal "32G", result[:current_size]
            assert_equal "42G", result[:new_size]
          end
        end

        describe "absolute resize" do
          it "uses parsed value as new size" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=32G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("50G")

            result = service.preflight(100, "scsi0", parsed, node: "pve1")

            assert_equal "scsi0", result[:disk]
            assert_equal "32G", result[:current_size]
            assert_equal "50G", result[:new_size]
          end
        end

        describe "volume not found" do
          it "raises VolumeNotFoundError when volume key missing" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=32G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("+10G")

            assert_raises(ResizeVolume::VolumeNotFoundError) do
              service.preflight(100, "virtio0", parsed, node: "pve1")
            end
          end

          it "raises VolumeNotFoundError when size not extractable" do
            config = { scsi0: "local-lvm:vm-100-disk-0" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("+10G")

            assert_raises(ResizeVolume::VolumeNotFoundError) do
              service.preflight(100, "scsi0", parsed, node: "pve1")
            end
          end
        end

        describe "size too small (absolute)" do
          it "raises SizeTooSmallError when absolute size equals current" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=32G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("32G")

            assert_raises(ResizeVolume::SizeTooSmallError) do
              service.preflight(100, "scsi0", parsed, node: "pve1")
            end
          end

          it "raises SizeTooSmallError when absolute size less than current" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=32G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("16G")

            assert_raises(ResizeVolume::SizeTooSmallError) do
              service.preflight(100, "scsi0", parsed, node: "pve1")
            end
          end
        end

        describe "container rootfs format" do
          it "handles rootfs disk format" do
            config = { rootfs: "local-lvm:subvol-200-disk-0,size=8G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("+2G")

            result = service.preflight(200, "rootfs", parsed, node: "pve1")

            assert_equal "rootfs", result[:disk]
            assert_equal "8G", result[:current_size]
            assert_equal "10G", result[:new_size]
          end
        end

        describe "cross-unit relative resize" do
          it "converts units when adding T to G" do
            config = { scsi0: "local-lvm:vm-100-disk-0,size=512G" }
            repo = build_mock_repo(config)
            service = ResizeVolume.new(repository: repo)
            parsed = ResizeVolume.parse_size("+1T")

            result = service.preflight(100, "scsi0", parsed, node: "pve1")

            assert_equal "1536G", result[:new_size]
          end
        end
      end

      # --- #perform ---

      describe "#perform" do
        describe "happy path" do
          it "calls repository resize and returns successful result" do
            resize_args = nil
            repo = Object.new
            repo.define_singleton_method(:resize) do |id, node, disk:, size:|
              resize_args = { id: id, node: node, disk: disk, size: size }
              nil
            end

            service = ResizeVolume.new(repository: repo)
            result = service.perform(100, "scsi0", "+10G", node: "pve1")

            assert result.successful?
            assert_equal :resize_volume, result.operation
            assert_equal({ id: 100, node: "pve1", disk: "scsi0", size: "+10G" }, result.resource)

            assert_equal({ id: 100, node: "pve1", disk: "scsi0", size: "+10G" }, resize_args)
          end
        end

        describe "API error" do
          it "returns failed result on exception" do
            repo = Object.new
            repo.define_singleton_method(:resize) do |_id, _node, disk:, size:|
              raise StandardError, "API connection refused"
            end

            service = ResizeVolume.new(repository: repo)
            result = service.perform(100, "scsi0", "+10G", node: "pve1")

            assert result.failed?
            assert_equal :resize_volume, result.operation
            assert_equal "API connection refused", result.error
            assert_equal({ id: 100, node: "pve1", disk: "scsi0" }, result.resource)
          end
        end
      end
    end
  end
end
