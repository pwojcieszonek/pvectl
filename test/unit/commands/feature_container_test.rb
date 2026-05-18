# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class FeatureContainerTest < Minitest::Test
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

      def test_resource_type_is_set_to_container
        assert_equal :container, FeatureContainer::RESOURCE_TYPE
      end

      def test_supported_resources_includes_container_and_ct
        assert_includes FeatureContainer::SUPPORTED_RESOURCES, "container"
        assert_includes FeatureContainer::SUPPORTED_RESOURCES, "ct"
      end

      def test_class_responds_to_execute
        assert_respond_to FeatureContainer, :execute
      end

      def test_execute_returns_usage_error_when_id_missing
        result = FeatureContainer.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "CTID"
      end

      def test_execute_returns_usage_error_when_feature_missing
        result = FeatureContainer.execute(["200"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "FEATURE"
      end

      def test_execute_returns_usage_error_when_id_not_numeric
        result = FeatureContainer.execute(["abc", "snapshot"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid CTID"
      end

      def test_execute_returns_usage_error_when_feature_unknown
        result = FeatureContainer.execute(["200", "bogus"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid feature"
      end
    end
  end
end
