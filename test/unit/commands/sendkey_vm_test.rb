# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class SendkeyVmTest < Minitest::Test
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

      # ------------------------------------------------------------------
      # Class shape
      # ------------------------------------------------------------------

      def test_class_exists
        assert_kind_of Class, SendkeyVm
      end

      def test_class_responds_to_execute
        assert_respond_to SendkeyVm, :execute
      end

      def test_class_responds_to_register
        assert_respond_to SendkeyVm, :register
      end

      # ------------------------------------------------------------------
      # Argument validation
      # ------------------------------------------------------------------

      def test_missing_vmid_returns_usage_error
        exit_code = SendkeyVm.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "VMID"
      end

      def test_missing_key_returns_usage_error
        exit_code = SendkeyVm.execute(["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "key"
      end

      def test_non_numeric_vmid_returns_usage_error
        exit_code = SendkeyVm.execute(["abc", "ret"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "VMID"
      end

      def test_empty_key_returns_usage_error
        exit_code = SendkeyVm.execute(["100", ""], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "key"
      end
    end
  end
end
