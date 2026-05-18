# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class MoveDiskVmTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_vm
        assert_equal :vm, MoveDiskVm::RESOURCE_TYPE
      end

      def test_supported_resources_includes_vm
        assert_includes MoveDiskVm::SUPPORTED_RESOURCES, "vm"
      end

      def test_class_responds_to_execute
        assert_respond_to MoveDiskVm, :execute
      end

      def test_execute_returns_usage_error_when_target_missing
        result = MoveDiskVm.execute(["100", "scsi0"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--target is required"
      end

      def test_execute_returns_usage_error_when_vmid_missing
        result = MoveDiskVm.execute([], { target: "storage2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "VMID and DISK are required"
      end

      def test_execute_returns_usage_error_when_disk_missing
        result = MoveDiskVm.execute(["100"], { target: "storage2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "VMID and DISK are required"
      end

      def test_execute_returns_usage_error_when_vmid_not_numeric
        result = MoveDiskVm.execute(["abc", "scsi0"], { target: "storage2", yes: true }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid VMID"
      end

      def test_execute_returns_usage_error_when_format_invalid
        result = MoveDiskVm.execute(
          ["100", "scsi0"],
          { target: "storage2", format: "bogus", yes: true },
          {}
        )

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid format"
      end
    end
  end
end
