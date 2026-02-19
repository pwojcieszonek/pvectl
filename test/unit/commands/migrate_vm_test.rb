# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class MigrateVmTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_vm
        assert_equal :vm, MigrateVm::RESOURCE_TYPE
      end

      def test_supported_resources_includes_vm
        assert_includes MigrateVm::SUPPORTED_RESOURCES, "vm"
      end

      def test_class_responds_to_execute
        assert_respond_to MigrateVm, :execute
      end

      def test_execute_returns_usage_error_when_target_missing
        result = MigrateVm.execute(["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--target is required"
      end

      def test_execute_returns_usage_error_when_restart_used_for_vm
        result = MigrateVm.execute(["100"], { target: "pve2", restart: true }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--restart is only supported for containers"
      end

      def test_execute_returns_usage_error_when_no_ids_all_or_selectors
        result = MigrateVm.execute([], { target: "pve2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
      end
    end
  end
end
