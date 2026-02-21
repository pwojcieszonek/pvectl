# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class CloneVmTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        @original_stdout = $stdout
        $stderr = StringIO.new
        $stdout = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
        $stdout = @original_stdout
      end

      def test_returns_usage_error_when_no_vmid_provided
        exit_code = CloneVm.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      def test_error_message_when_no_vmid_provided
        CloneVm.execute([], {}, {})

        assert_includes $stderr.string, "Source VMID required"
      end

      def test_class_responds_to_execute
        assert_respond_to CloneVm, :execute
      end

      def test_returns_usage_error_when_nil_vmid
        exit_code = CloneVm.execute([nil], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      describe "with config flags" do
        before do
          @original_stderr = $stderr
          @original_stdout = $stdout
          $stderr = StringIO.new
          $stdout = StringIO.new
        end

        after do
          $stderr = @original_stderr
          $stdout = @original_stdout
        end

        it "rejects async mode with config flags" do
          exit_code = CloneVm.execute(
            ["100"], { async: true, cores: 4 }, {}
          )

          assert_equal ExitCodes::USAGE_ERROR, exit_code
          assert_includes $stderr.string, "Config flags require sync mode"
        end

        it "allows async mode without config flags" do
          # Should NOT return USAGE_ERROR (will fail at config load, but that's ok)
          exit_code = CloneVm.execute(["100"], { async: true }, {})

          refute_equal ExitCodes::USAGE_ERROR, exit_code
        end

        it "displays summary when config flags are provided and user declines" do
          # Simulate user typing "n" (decline)
          original_stdin = $stdin
          $stdin = StringIO.new("n\n")

          exit_code = CloneVm.execute(["100"], { cores: 4 }, {})

          assert_equal ExitCodes::SUCCESS, exit_code
          assert_includes $stdout.string, "Clone VM - Summary"
          assert_includes $stdout.string, "Config changes"
          assert_includes $stdout.string, "4 cores"
          assert_includes $stdout.string, "Clone and configure this VM?"
        ensure
          $stdin = original_stdin
        end

        it "skips confirmation with --yes flag" do
          # With --yes, should skip confirmation and proceed to config load
          # (will fail at config load, that's expected - we're testing it doesn't ask)
          CloneVm.execute(["100"], { cores: 4, yes: true }, {})

          # Should NOT be SUCCESS (that would mean it asked and user declined)
          # It should try to proceed and hit config error (GENERAL_ERROR)
          refute_includes $stdout.string, "Clone and configure this VM?"
        end

        it "does not show summary when no config flags provided" do
          # Without config flags, should go straight to clone (and fail at config)
          CloneVm.execute(["100"], {}, {})

          refute_includes $stdout.string, "Clone VM - Summary"
        end
      end
    end
  end
end
