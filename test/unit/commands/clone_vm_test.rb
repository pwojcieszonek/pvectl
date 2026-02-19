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
    end
  end
end
