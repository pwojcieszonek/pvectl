# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class FeatureVmTest < Minitest::Test
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

      def test_resource_type_is_set_to_vm
        assert_equal :vm, FeatureVm::RESOURCE_TYPE
      end

      def test_supported_resources_includes_vm
        assert_includes FeatureVm::SUPPORTED_RESOURCES, "vm"
      end

      def test_class_responds_to_execute
        assert_respond_to FeatureVm, :execute
      end

      def test_execute_returns_usage_error_when_id_missing
        result = FeatureVm.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "VMID"
      end

      def test_execute_returns_usage_error_when_feature_missing
        result = FeatureVm.execute(["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "FEATURE"
      end

      def test_execute_returns_usage_error_when_id_not_numeric
        result = FeatureVm.execute(["abc", "clone"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid VMID"
      end

      def test_execute_returns_usage_error_when_feature_unknown
        result = FeatureVm.execute(["100", "bogus"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Invalid feature"
      end

      def test_accepts_known_features
        # No connection setup — we just check validation fails *after* arg checks.
        # Since no config is loaded, perform_operation will rescue and return
        # GENERAL_ERROR; what matters is we don't get USAGE_ERROR for valid features.
        %w[clone snapshot copy].each do |feature|
          $stderr = StringIO.new
          result = FeatureVm.execute(["100", feature], {}, {})
          refute_equal ExitCodes::USAGE_ERROR, result,
                       "feature #{feature} should be accepted, got USAGE_ERROR; stderr=#{$stderr.string}"
        end
      end
    end
  end
end
