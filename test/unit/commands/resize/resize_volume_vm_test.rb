# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Resize
      class ResizeVolumeVmTest < Minitest::Test
        describe "argument validation" do
          before do
            @original_stderr = $stderr
            $stderr = StringIO.new
          end

          after do
            $stderr = @original_stderr
          end

          it "returns usage error when VMID is missing" do
            cmd = ResizeVolumeVm.new([], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "VMID"
          end

          it "returns usage error when volume is missing" do
            cmd = ResizeVolumeVm.new(["100"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "VOLUME"
          end

          it "returns usage error when size is missing" do
            cmd = ResizeVolumeVm.new(["100", "scsi0"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "SIZE"
          end

          it "returns usage error for invalid size format" do
            cmd = ResizeVolumeVm.new(["100", "scsi0", "abc"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "Invalid size"
          end
        end

        describe "template hooks" do
          it "returns VM as resource_label" do
            cmd = ResizeVolumeVm.new([], {}, {})
            assert_equal "VM", cmd.send(:resource_label)
          end

          it "returns VMID as resource_id_label" do
            cmd = ResizeVolumeVm.new([], {}, {})
            assert_equal "VMID", cmd.send(:resource_id_label)
          end
        end
      end
    end
  end
end
