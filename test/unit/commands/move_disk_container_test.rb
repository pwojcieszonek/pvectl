# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class MoveDiskContainerTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_container
        assert_equal :container, MoveDiskContainer::RESOURCE_TYPE
      end

      def test_supported_resources_includes_container
        assert_includes MoveDiskContainer::SUPPORTED_RESOURCES, "container"
      end

      def test_supported_resources_includes_ct
        assert_includes MoveDiskContainer::SUPPORTED_RESOURCES, "ct"
      end

      def test_class_responds_to_execute
        assert_respond_to MoveDiskContainer, :execute
      end

      def test_execute_returns_usage_error_when_target_missing
        result = MoveDiskContainer.execute(["200", "rootfs"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--target is required"
      end

      def test_execute_returns_usage_error_when_ctid_missing
        result = MoveDiskContainer.execute([], { target: "storage2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "CTID and VOLUME are required"
      end

      def test_execute_returns_usage_error_when_volume_missing
        result = MoveDiskContainer.execute(["200"], { target: "storage2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "CTID and VOLUME are required"
      end

      def test_execute_returns_usage_error_when_ctid_not_numeric
        result = MoveDiskContainer.execute(["abc", "rootfs"], { target: "storage2", yes: true }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid CTID"
      end

      def test_execute_returns_usage_error_when_format_provided
        result = MoveDiskContainer.execute(
          ["200", "rootfs"],
          { target: "storage2", format: "qcow2", yes: true },
          {}
        )

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--format is not supported for containers"
      end
    end
  end
end
