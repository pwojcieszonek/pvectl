# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditNodeTest < Minitest::Test
      def build_node(attrs = {})
        Models::Node.new({ name: "pve1", status: "online" }.merge(attrs))
      end

      def build_config(extras = {})
        { description: "production node", wakeonlan: "00:11:22:33:44:55", digest: "abc123" }.merge(extras)
      end

      # Builds an editor callable that writes new content to the temp file.
      # Content must use string keys for valid YAML (matching service output).
      def build_editor(new_content)
        ->(path) { File.write(path, new_content) }
      end

      # Noop editor — does not modify the temp file, triggering cancellation.
      def build_noop_editor
        ->(_path) {}
      end

      # Helper to generate string-keyed YAML (matching the service format).
      def to_editable_yaml(hash)
        hash.reject { |k, _| k == :digest }.transform_keys(&:to_s).to_yaml
      end

      def test_applies_changes_to_api
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        update_params = nil
        node_repo.expect(:update, nil) do |name, params|
          update_params = params
          true
        end

        # Editor changes description
        edited_yaml = { "description" => "updated node", "wakeonlan" => "00:11:22:33:44:55" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert_kind_of Models::NodeOperationResult, result
        assert_equal :edit, result.operation
        assert_equal "updated node", update_params[:description]
        assert_equal "abc123", update_params[:digest]
        node_repo.verify
      end

      def test_cancelled_edit_returns_nil
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        # Noop editor — same content, EditorSession returns nil
        editor_session = EditorSession.new(editor: build_noop_editor)

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert_nil result
        node_repo.verify
      end

      def test_no_changes_returns_nil
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        # Editor writes back the same editable config (string keys, no digest)
        same_yaml = to_editable_yaml(config)
        editor_session = EditorSession.new(editor: build_editor(same_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert_nil result
        node_repo.verify
      end

      def test_node_not_found
        node_repo = Minitest::Mock.new
        node_repo.expect(:get, nil, ["pve1"])

        service = EditNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/not found/, result.error)
        assert_kind_of Models::NodeOperationResult, result
        node_repo.verify
      end

      def test_dry_run_does_not_call_api
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        edited_yaml = { "description" => "new desc", "wakeonlan" => "00:11:22:33:44:55" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session, options: { dry_run: true })
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert result.resource[:diff]
        # update was never expected — if called, mock would raise
        node_repo.verify
      end

      def test_api_error
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])
        node_repo.expect(:update, nil) do |_name, _params|
          raise StandardError, "permission denied"
        end

        edited_yaml = { "description" => "new desc", "wakeonlan" => "00:11:22:33:44:55" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/permission denied/, result.error)
        node_repo.verify
      end

      def test_removed_keys_sends_delete_param
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        update_params = nil
        node_repo.expect(:update, nil) do |_name, params|
          update_params = params
          true
        end

        # Editor removes wakeonlan key
        edited_yaml = { "description" => "production node" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert_includes update_params[:delete], "wakeonlan"
        node_repo.verify
      end

      def test_diff_contains_changes
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        node_repo.expect(:update, nil) do |_name, _params|
          true
        end

        edited_yaml = { "description" => "updated", "wakeonlan" => "00:11:22:33:44:55",
                        "acme" => "domains=example.com" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditNode.new(node_repository: node_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        diff = result.resource[:diff]
        assert_includes diff[:changed].keys, :description
        assert_includes diff[:added].keys, :acme
        node_repo.verify
      end
    end
  end
end
