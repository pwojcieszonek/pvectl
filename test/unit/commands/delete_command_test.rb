# frozen_string_literal: true

require "test_helper"
require "stringio"

module Pvectl
  module Commands
    # Test class that includes DeleteCommand module
    class TestDeleteVm
      include DeleteCommand
      RESOURCE_TYPE = :vm
      SUPPORTED_RESOURCES = %w[vm].freeze
    end

    class DeleteCommandTest < Minitest::Test
      def setup
        @original_stdout = $stdout
        @original_stderr = $stderr
        $stdout = StringIO.new
        $stderr = StringIO.new
      end

      def teardown
        $stdout = @original_stdout
        $stderr = @original_stderr
      end

      def test_module_exists
        assert_kind_of Module, Pvectl::Commands::DeleteCommand
      end

      def test_class_methods_module_exists
        assert_kind_of Module, Pvectl::Commands::DeleteCommand::ClassMethods
      end

      def test_including_class_gets_execute_class_method
        assert TestDeleteVm.respond_to?(:execute)
      end
    end

    class DeleteCommandValidationTest < Minitest::Test
      def setup
        @original_stdout = $stdout
        @original_stderr = $stderr
        $stdout = StringIO.new
        $stderr = StringIO.new
      end

      def teardown
        $stdout = @original_stdout
        $stderr = @original_stderr
      end

      def test_returns_usage_error_when_resource_type_is_missing
        result = TestDeleteVm.execute(nil, ["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Resource type required"
      end

      def test_returns_usage_error_when_resource_type_is_unsupported
        result = TestDeleteVm.execute("nodes", ["100"], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "Unsupported resource"
      end

      def test_returns_usage_error_when_no_ids_all_or_selectors_provided
        result = TestDeleteVm.execute("vm", [], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, result
        assert_includes $stderr.string, "VMID, --all, or -l selector required"
      end

      def test_accepts_resource_ids
        cmd = TestDeleteVm.new("vm", %w[100 101], {}, {})
        assert_equal %w[100 101], cmd.instance_variable_get(:@resource_ids)
      end

      def test_accepts_all_flag_without_vmids
        cmd = TestDeleteVm.new("vm", [], { all: true }, {})
        assert_equal [], cmd.instance_variable_get(:@resource_ids)
        assert cmd.instance_variable_get(:@options)[:all]
      end

      def test_accepts_selector_without_vmids
        cmd = TestDeleteVm.new("vm", [], { selector: ["status=stopped"] }, {})
        assert_equal [], cmd.instance_variable_get(:@resource_ids)
        assert cmd.instance_variable_get(:@options)[:selector]
      end
    end

    class DeleteCommandConfirmationTest < Minitest::Test
      # Test helper class to expose private methods for testing
      class TestableDeleteCommand
        include DeleteCommand
        RESOURCE_TYPE = :vm
        SUPPORTED_RESOURCES = %w[vm].freeze

        # Expose private method for testing
        def test_confirm_operation(resources)
          confirm_operation(resources)
        end
      end

      def setup
        @vm1 = Models::Vm.new(vmid: 100, name: "web-server-1", node: "pve1")
        @vm2 = Models::Vm.new(vmid: 101, name: "web-server-2", node: "pve1")
        @original_stdin = $stdin
        @original_stdout = $stdout
        @original_stderr = $stderr
      end

      def teardown
        $stdin = @original_stdin
        $stdout = @original_stdout
        $stderr = @original_stderr
      end

      def test_always_requires_confirmation_even_for_single_resource
        $stdout = StringIO.new
        $stdin = StringIO.new("n\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        result = cmd.test_confirm_operation([@vm1])

        refute result, "Single resource delete should require confirmation"
        assert_includes $stdout.string, "100"
      end

      def test_skips_confirmation_with_yes_flag
        cmd = TestableDeleteCommand.new("vm", ["100"], { yes: true }, {})
        result = cmd.test_confirm_operation([@vm1])

        assert result, "--yes flag should skip confirmation"
      end

      def test_confirmation_shows_irreversible_warning
        $stdout = StringIO.new
        $stdin = StringIO.new("n\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        cmd.test_confirm_operation([@vm1])

        assert_includes $stdout.string, "IRREVERSIBLE"
      end

      def test_confirmation_shows_keep_disks_message
        $stdout = StringIO.new
        $stdin = StringIO.new("n\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], { "keep-disks": true }, {})
        cmd.test_confirm_operation([@vm1])

        assert_includes $stdout.string, "Disks will be preserved"
      end

      def test_confirms_with_y_response
        $stdout = StringIO.new
        $stdin = StringIO.new("y\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        result = cmd.test_confirm_operation([@vm1])

        assert result
      end

      def test_confirms_with_yes_response
        $stdout = StringIO.new
        $stdin = StringIO.new("yes\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        result = cmd.test_confirm_operation([@vm1])

        assert result
      end

      def test_aborts_with_n_response
        $stdout = StringIO.new
        $stdin = StringIO.new("n\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        result = cmd.test_confirm_operation([@vm1])

        refute result
      end

      def test_aborts_with_empty_response
        $stdout = StringIO.new
        $stdin = StringIO.new("\n")

        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        result = cmd.test_confirm_operation([@vm1])

        refute result, "Empty response should default to No"
      end

      def test_multi_resource_confirmation_lists_all
        $stdout = StringIO.new
        $stdin = StringIO.new("n\n")

        cmd = TestableDeleteCommand.new("vm", %w[100 101], {}, {})
        cmd.test_confirm_operation([@vm1, @vm2])

        output = $stdout.string
        assert_includes output, "2 VMs"
        assert_includes output, "100"
        assert_includes output, "101"
      end
    end

    class DeleteCommandServiceOptionsTest < Minitest::Test
      # Test helper class to expose private methods for testing
      class TestableDeleteCommand
        include DeleteCommand
        RESOURCE_TYPE = :vm
        SUPPORTED_RESOURCES = %w[vm].freeze

        # Expose private method for testing
        def test_service_options
          service_options
        end
      end

      def test_service_options_includes_timeout
        cmd = TestableDeleteCommand.new("vm", ["100"], { timeout: 120 }, {})
        opts = cmd.test_service_options
        assert_equal 120, opts[:timeout]
      end

      def test_service_options_includes_async
        cmd = TestableDeleteCommand.new("vm", ["100"], { async: true }, {})
        opts = cmd.test_service_options
        assert_equal true, opts[:async]
      end

      def test_service_options_includes_force
        cmd = TestableDeleteCommand.new("vm", ["100"], { force: true }, {})
        opts = cmd.test_service_options
        assert_equal true, opts[:force]
      end

      def test_service_options_includes_keep_disks
        cmd = TestableDeleteCommand.new("vm", ["100"], { "keep-disks": true }, {})
        opts = cmd.test_service_options
        assert_equal true, opts[:keep_disks]
      end

      def test_service_options_includes_purge
        cmd = TestableDeleteCommand.new("vm", ["100"], { purge: true }, {})
        opts = cmd.test_service_options
        assert_equal true, opts[:purge]
      end

      def test_service_options_includes_fail_fast
        cmd = TestableDeleteCommand.new("vm", ["100"], { "fail-fast": true }, {})
        opts = cmd.test_service_options
        assert_equal true, opts[:fail_fast]
      end

      def test_service_options_excludes_unset_options
        cmd = TestableDeleteCommand.new("vm", ["100"], {}, {})
        opts = cmd.test_service_options

        assert_nil opts[:timeout]
        assert_nil opts[:async]
        assert_nil opts[:force]
        assert_nil opts[:keep_disks]
        assert_nil opts[:purge]
        assert_nil opts[:fail_fast]
      end
    end

    class DeleteCommandResolveResourcesTest < Minitest::Test
      # Test helper class to expose private methods for testing
      class TestableDeleteCommand
        include DeleteCommand
        RESOURCE_TYPE = :vm
        SUPPORTED_RESOURCES = %w[vm].freeze

        # Expose private method for testing
        def test_resolve_resources(connection)
          resolve_resources(connection)
        end
      end

      def setup
        @vm1 = Models::Vm.new(vmid: 100, name: "web-1", node: "pve1")
        @vm2 = Models::Vm.new(vmid: 101, name: "web-2", node: "pve1")
        @vm3 = Models::Vm.new(vmid: 102, name: "db-1", node: "pve2")
      end

      def test_resolve_resources_with_vmids
        mock_repo = Minitest::Mock.new
        mock_repo.expect(:get, @vm1, [100])
        mock_repo.expect(:get, @vm2, [101])

        mock_connection = Object.new
        Repositories::Vm.stub(:new, mock_repo) do
          cmd = TestableDeleteCommand.new("vm", %w[100 101], {}, {})
          resources = cmd.test_resolve_resources(mock_connection)

          assert_equal 2, resources.size
          assert_equal [@vm1, @vm2], resources
        end

        mock_repo.verify
      end

      def test_resolve_resources_with_all_flag
        mock_repo = Minitest::Mock.new
        mock_repo.expect(:list, [@vm1, @vm2, @vm3]) { |node:| node.nil? }

        mock_connection = Object.new
        Repositories::Vm.stub(:new, mock_repo) do
          cmd = TestableDeleteCommand.new("vm", [], { all: true }, {})
          resources = cmd.test_resolve_resources(mock_connection)

          assert_equal 3, resources.size
        end

        mock_repo.verify
      end

      def test_resolve_resources_with_node_filter
        mock_repo = Minitest::Mock.new
        mock_repo.expect(:list, [@vm1, @vm2]) { |node:| node == "pve1" }

        mock_connection = Object.new
        Repositories::Vm.stub(:new, mock_repo) do
          cmd = TestableDeleteCommand.new("vm", [], { all: true, node: "pve1" }, {})
          resources = cmd.test_resolve_resources(mock_connection)

          assert_equal 2, resources.size
        end

        mock_repo.verify
      end

      def test_resolve_resources_returns_empty_without_vmids_all_or_selector
        cmd = TestableDeleteCommand.new("vm", [], {}, {})
        mock_connection = Object.new

        resources = cmd.test_resolve_resources(mock_connection)

        assert_empty resources
      end
    end

    class DeleteCommandContainerTest < Minitest::Test
      # Test class for container delete
      class TestDeleteContainer
        include DeleteCommand
        RESOURCE_TYPE = :container
        SUPPORTED_RESOURCES = %w[container].freeze
      end

      def setup
        @original_stdout = $stdout
        @original_stderr = $stderr
        $stdout = StringIO.new
        $stderr = StringIO.new
      end

      def teardown
        $stdout = @original_stdout
        $stderr = @original_stderr
      end

      def test_container_resource_type
        cmd = TestDeleteContainer.new("container", ["100"], {}, {})
        assert_equal :container, cmd.send(:resource_type_symbol)
      end

      def test_container_supported_resources
        cmd = TestDeleteContainer.new("container", ["100"], {}, {})
        assert_equal %w[container], cmd.send(:supported_types)
      end

      def test_container_validation_accepts_container_type
        TestDeleteContainer.execute("container", [], {}, {})

        # Should fail with "VMID, --all, or -l selector required", not "Unsupported resource"
        assert_includes $stderr.string, "VMID, --all, or -l selector required"
      end
    end
  end
end
