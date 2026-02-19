# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class EditContainerTest < Minitest::Test
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
        assert_respond_to EditContainer, :execute
      end

      def test_includes_edit_resource_command
        assert_includes EditContainer.ancestors, EditResourceCommand
      end

      def test_returns_usage_error_without_ctid
        exit_code = EditContainer.execute([], {}, {})

        assert_equal ExitCodes::USAGE_ERROR, exit_code
        assert_includes $stderr.string, "CTID is required"
      end

      # --- template methods ---

      def test_resource_label_returns_container
        cmd = EditContainer.new([], {}, {})
        assert_equal "container", cmd.send(:resource_label)
      end

      def test_resource_id_label_returns_ctid
        cmd = EditContainer.new([], {}, {})
        assert_equal "CTID", cmd.send(:resource_id_label)
      end

      def test_execute_params_returns_ctid_hash
        cmd = EditContainer.new([], {}, {})
        assert_equal({ ctid: 200 }, cmd.send(:execute_params, 200))
      end

      # --- service_options ---

      def test_service_options_includes_dry_run_when_set
        cmd = EditContainer.new([], { "dry-run": true }, {})
        assert_equal true, cmd.send(:service_options)[:dry_run]
      end

      def test_service_options_returns_empty_hash_when_nothing_set
        cmd = EditContainer.new([], {}, {})
        assert_equal({}, cmd.send(:service_options))
      end

      # --- execute with cancelled edit (nil from service) ---

      def test_execute_prints_cancelled_message_when_service_returns_nil
        cmd = EditContainer.new(["200"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, nil, [], ctid: 200)

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
        diff = { changed: { cores: [2, 4] }, added: {}, removed: [] }
        container = Models::Container.new(vmid: 200, node: "pve1")
        result = Models::ContainerOperationResult.new(
          operation: :edit, container: container, resource: { ctid: 200, diff: diff },
          success: true
        )

        cmd = EditContainer.new(["200"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], ctid: 200)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::SUCCESS, exit_code
              assert_includes $stdout.string, "container 200 updated successfully."
              assert_includes $stdout.string, "Changes:"
            end
          end
        end

        mock_service.verify
      end

      # --- execute with dry-run ---

      def test_execute_shows_dry_run_notice
        diff = { changed: { memory: [512, 1024] }, added: {}, removed: [] }
        container = Models::Container.new(vmid: 200, node: "pve1")
        result = Models::ContainerOperationResult.new(
          operation: :edit, container: container, resource: { ctid: 200, diff: diff },
          success: true
        )

        cmd = EditContainer.new(["200"], { "dry-run": true }, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], ctid: 200)

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
        container = Models::Container.new(vmid: 200, node: "pve1")
        result = Models::ContainerOperationResult.new(
          operation: :edit, container: container, resource: { ctid: 200 },
          success: false, error: "Container 200 not found"
        )

        cmd = EditContainer.new(["200"], {}, {})

        mock_service = Minitest::Mock.new
        mock_service.expect(:execute, result, [], ctid: 200)

        cmd.stub(:load_config, nil) do
          cmd.stub(:build_edit_service, mock_service) do
            Pvectl::Connection.stub(:new, Object.new) do
              exit_code = cmd.execute

              assert_equal ExitCodes::GENERAL_ERROR, exit_code
              assert_includes $stderr.string, "Container 200 not found"
            end
          end
        end

        mock_service.verify
      end

      # --- build_editor_session ---

      def test_build_editor_session_returns_nil_without_editor_option
        cmd = EditContainer.new([], {}, {})
        assert_nil cmd.send(:build_editor_session)
      end

      def test_build_editor_session_returns_editor_session_with_option
        cmd = EditContainer.new([], { editor: "vim" }, {})
        session = cmd.send(:build_editor_session)
        assert_instance_of Pvectl::EditorSession, session
      end
    end
  end
end
