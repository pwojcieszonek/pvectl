# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Resize
      class ResizeDiskCtTest < Minitest::Test
        describe "argument validation" do
          it "returns usage error when CTID is missing" do
            cmd = ResizeDiskCt.new([], {}, {})
            captured = StringIO.new
            original_stderr = $stderr
            $stderr = captured

            exit_code = cmd.execute

            $stderr = original_stderr
            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes captured.string, "CTID"
          end

          it "returns usage error when disk is missing" do
            cmd = ResizeDiskCt.new(["200"], {}, {})
            captured = StringIO.new
            original_stderr = $stderr
            $stderr = captured

            exit_code = cmd.execute

            $stderr = original_stderr
            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes captured.string, "DISK"
          end

          it "returns usage error when size is missing" do
            cmd = ResizeDiskCt.new(["200", "rootfs"], {}, {})
            captured = StringIO.new
            original_stderr = $stderr
            $stderr = captured

            exit_code = cmd.execute

            $stderr = original_stderr
            assert_equal ExitCodes::USAGE_ERROR, exit_code
            assert_includes captured.string, "SIZE"
          end
        end

        describe "template hooks" do
          it "returns container as resource_label" do
            cmd = ResizeDiskCt.new([], {}, {})
            assert_equal "container", cmd.send(:resource_label)
          end

          it "returns CTID as resource_id_label" do
            cmd = ResizeDiskCt.new([], {}, {})
            assert_equal "CTID", cmd.send(:resource_id_label)
          end
        end
      end
    end
  end
end
