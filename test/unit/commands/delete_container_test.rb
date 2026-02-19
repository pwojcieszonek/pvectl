# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class DeleteContainerTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_container
        assert_equal :container, DeleteContainer::RESOURCE_TYPE
      end

      def test_supported_resources_includes_container
        assert_includes DeleteContainer::SUPPORTED_RESOURCES, "container"
      end

      def test_supported_resources_includes_ct
        assert_includes DeleteContainer::SUPPORTED_RESOURCES, "ct"
      end

      def test_execute_returns_usage_error_for_missing_resource_type
        result = DeleteContainer.execute(nil, ["200"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
      end

      def test_execute_accepts_ct_alias
        result = DeleteContainer.execute("ct", [], {}, {})

        # Should fail on "no IDs" not "unsupported resource"
        assert_equal ExitCodes::USAGE_ERROR, result
        refute_includes $stderr.string, "Unsupported resource"
      end

      def test_execute_returns_usage_error_for_unsupported_resource_type
        result = DeleteContainer.execute("vm", ["200"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Unsupported resource"
      end
    end
  end
end
