# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class TemplateVmTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_vm
        assert_equal :vm, TemplateVm::RESOURCE_TYPE
      end

      def test_supported_resources_includes_vm
        assert_includes TemplateVm::SUPPORTED_RESOURCES, "vm"
      end

      def test_execute_returns_usage_error_for_missing_resource_type
        result = TemplateVm.execute(nil, ["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
      end

      def test_execute_returns_usage_error_for_unsupported_resource_type
        result = TemplateVm.execute("container", ["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Unsupported resource"
      end

      def test_execute_returns_usage_error_for_missing_ids
        result = TemplateVm.execute("vm", [], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
      end
    end
  end
end
