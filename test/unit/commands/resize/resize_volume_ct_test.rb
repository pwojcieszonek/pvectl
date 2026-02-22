# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Resize
      class ResizeVolumeCtTest < Minitest::Test
        describe "argument validation" do
          before do
            @original_stderr = $stderr
            $stderr = StringIO.new
          end

          after do
            $stderr = @original_stderr
          end

          it "returns usage error when CTID is missing" do
            cmd = ResizeVolumeCt.new([], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "CTID"
          end

          it "returns usage error when volume is missing" do
            cmd = ResizeVolumeCt.new(["200"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "VOLUME"
          end

          it "returns usage error when size is missing" do
            cmd = ResizeVolumeCt.new(["200", "rootfs"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "SIZE"
          end

          it "returns usage error for invalid size format" do
            cmd = ResizeVolumeCt.new(["200", "rootfs", "xyz"], {}, {})
            exit_code = cmd.execute

            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes $stderr.string, "Invalid size"
          end
        end

        describe "template hooks" do
          it "returns container as resource_label" do
            cmd = ResizeVolumeCt.new([], {}, {})
            assert_equal "container", cmd.send(:resource_label)
          end

          it "returns CTID as resource_id_label" do
            cmd = ResizeVolumeCt.new([], {}, {})
            assert_equal "CTID", cmd.send(:resource_id_label)
          end
        end
      end
    end
  end
end
