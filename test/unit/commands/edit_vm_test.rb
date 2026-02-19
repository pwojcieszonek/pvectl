# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class EditVmTest < Minitest::Test
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

      # --- .execute ---

      def test_class_responds_to_execute
        assert_respond_to EditVm, :execute
      end

      def test_includes_edit_resource_command
        assert_includes EditVm.ancestors, EditResourceCommand
      end

      def test_returns_usage_error_without_vmid
        exit_code = EditVm.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "VMID is required"
      end

      # --- template methods ---

      def test_resource_label_returns_vm
        cmd = EditVm.new([], {}, {})
        assert_equal "VM", cmd.send(:resource_label)
      end

      def test_resource_id_label_returns_vmid
        cmd = EditVm.new([], {}, {})
        assert_equal "VMID", cmd.send(:resource_id_label)
      end

      def test_execute_params_returns_vmid_hash
        cmd = EditVm.new([], {}, {})
        assert_equal({ vmid: 100 }, cmd.send(:execute_params, 100))
      end

      # --- service_options ---

      def test_service_options_includes_dry_run_when_set
        cmd = EditVm.new([], { "dry-run": true }, {})
        assert_equal true, cmd.send(:service_options)[:dry_run]
      end

      def test_service_options_returns_empty_hash_when_nothing_set
        cmd = EditVm.new([], {}, {})
        assert_equal({}, cmd.send(:service_options))
      end

      # --- execute with cancelled edit (nil from service) ---

      def test_execute_prints_cancelled_message_when_service_returns_nil
        cmd = EditVm.new(["100"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, nil, [], vmid: 100)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::SUCCESS, exit_code
              assert_includes $stdout.string, "Edit cancelled, no changes made."
            end
          end
        end

        mock_service.verify
      end

      # --- execute with successful result and diff ---

      def test_execute_displays_diff_and_success_message
        diff = { changed: { cores: [4, 8] }, added: {}, removed: [] }
        vm = Models::Vm.new(vmid: 100, node: "pve1")
        result = Models::VmOperationResult.new(
          operation: :edit, vm: vm, resource: { vmid: 100, diff: diff },
          success: true
        )

        cmd = EditVm.new(["100"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], vmid: 100)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::SUCCESS, exit_code
              assert_includes $stdout.string, "VM 100 updated successfully."
              assert_includes $stdout.string, "Changes:"
            end
          end
        end

        mock_service.verify
      end

      # --- execute with dry-run ---

      def test_execute_shows_dry_run_notice
        diff = { changed: { cores: [4, 8] }, added: {}, removed: [] }
        vm = Models::Vm.new(vmid: 100, node: "pve1")
        result = Models::VmOperationResult.new(
          operation: :edit, vm: vm, resource: { vmid: 100, diff: diff },
          success: true
        )

        cmd = EditVm.new(["100"], { "dry-run": true }, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], vmid: 100)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::SUCCESS, exit_code
              assert_includes $stdout.string, "(dry-run mode"
            end
          end
        end

        mock_service.verify
      end

      # --- execute with failed result ---

      def test_execute_returns_general_error_on_failure
        vm = Models::Vm.new(vmid: 100, node: "pve1")
        result = Models::VmOperationResult.new(
          operation: :edit, vm: vm, resource: { vmid: 100 },
          success: false, error: "VM 100 not found"
        )

        cmd = EditVm.new(["100"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], vmid: 100)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::GENERAL_ERROR, exit_code
              assert_includes $stderr.string, "VM 100 not found"
            end
          end
        end

        mock_service.verify
      end

      # --- build_editor_session ---

      def test_build_editor_session_returns_nil_without_editor_option
        cmd = EditVm.new([], {}, {})
        assert_nil cmd.send(:build_editor_session)
      end

      def test_build_editor_session_returns_editor_session_with_option
        cmd = EditVm.new([], { editor: "nano" }, {})
        session = cmd.send(:build_editor_session)
        assert_instance_of Pvectl::EditorSession, session
      end
    end
  end
end
