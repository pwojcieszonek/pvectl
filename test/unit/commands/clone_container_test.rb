# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class CloneContainerTest < Minitest::Test
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

      def test_returns_usage_error_when_no_ctid_provided
        exit_code = CloneContainer.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
      end

      def test_error_message_when_no_ctid_provided
        CloneContainer.execute([], {}, {})

        assert_includes $stderr.string, "Source CTID required"
      end

      def test_class_responds_to_execute
        assert_respond_to CloneContainer, :execute
      end

      def test_returns_usage_error_when_nil_ctid
        exit_code = CloneContainer.execute([nil], {}, {})

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
          exit_code = CloneContainer.execute(
            ["100"], { async: true, cores: 4 }, {}
          )

          assert_equal ExitCodes::USAGE_ERROR, exit_code
          assert_includes $stderr.string, "Config flags require sync mode"
        end

        it "allows async mode without config flags" do
          # Should NOT return USAGE_ERROR (will fail at config load, but that's ok)
          exit_code = CloneContainer.execute(["100"], { async: true }, {})

          refute_equal ExitCodes::USAGE_ERROR, exit_code
        end

        it "displays summary when config flags are provided and user declines" do
          # Simulate user typing "n" (decline)
          original_stdin = $stdin
          $stdin = StringIO.new("n\n")

          exit_code = CloneContainer.execute(["100"], { cores: 2 }, {})

          assert_equal ExitCodes::SUCCESS, exit_code
          assert_includes $stdout.string, "Clone Container - Summary"
          assert_includes $stdout.string, "Config changes"
          assert_includes $stdout.string, "2 cores"
          assert_includes $stdout.string, "Clone and configure this container?"
        ensure
          $stdin = original_stdin
        end

        it "skips confirmation with --yes flag" do
          # With --yes, should skip confirmation and proceed to config load
          # (will fail at config load, that's expected - we're testing it doesn't ask)
          CloneContainer.execute(["100"], { cores: 2, yes: true }, {})

          refute_includes $stdout.string, "Clone and configure this container?"
        end

        it "does not show summary when no config flags provided" do
          # Without config flags, should go straight to clone (and fail at config)
          CloneContainer.execute(["100"], {}, {})

          refute_includes $stdout.string, "Clone Container - Summary"
        end
      end
    end
  end
end
