# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class MigrateContainerTest < Minitest::Test
      def setup
        @original_stderr = $stderr
        $stderr = StringIO.new
      end

      def teardown
        $stderr = @original_stderr
      end

      def test_resource_type_is_set_to_container
        assert_equal :container, MigrateContainer::RESOURCE_TYPE
      end

      def test_supported_resources_includes_container
        assert_includes MigrateContainer::SUPPORTED_RESOURCES, "container"
      end

      def test_supported_resources_includes_ct
        assert_includes MigrateContainer::SUPPORTED_RESOURCES, "ct"
      end

      def test_class_responds_to_execute
        assert_respond_to MigrateContainer, :execute
      end

      def test_execute_returns_usage_error_when_target_missing
        result = MigrateContainer.execute(["200"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "--target is required"
      end

      def test_execute_allows_restart_flag_for_container
        # Should NOT return --restart error; should fail on something else (e.g., config)
        result = MigrateContainer.execute(["200"], { target: "pve2", restart: true }, {})

        refute_includes $stderr.string, "--restart is only supported for containers"
      end

      def test_execute_returns_usage_error_when_no_ids_all_or_selectors
        result = MigrateContainer.execute([], { target: "pve2" }, {})

        assert_equal ExitCodes::USAGE_ERROR, result
      end
    end
  end
end
