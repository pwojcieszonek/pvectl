# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditHostsTest < Minitest::Test
      ORIGINAL_HOSTS = "127.0.0.1 localhost\n192.168.1.1 pve1 pvelocalhost\n"

      def build_hosts(attrs = {})
        Models::HostsFile.new(
          { node: "pve1", data: ORIGINAL_HOSTS, digest: "abc123" }.merge(attrs)
        )
      end

      def build_editor(new_content)
        ->(path) { File.write(path, new_content) }
      end

      def build_noop_editor
        ->(_path) {}
      end

      def test_applies_changes_to_api_with_original_digest
        hosts = build_hosts

        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])

        received = {}
        hosts_repo.expect(:update, nil) do |name, data, digest|
          received[:name] = name
          received[:data] = data
          received[:digest] = digest
          true
        end

        new_content = "#{ORIGINAL_HOSTS}10.0.0.1 newhost\n"
        editor_session = EditorSession.new(editor: build_editor(new_content))

        service = EditHosts.new(hosts_repository: hosts_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert_kind_of Models::NodeOperationResult, result
        assert_equal :edit, result.operation
        assert_equal "pve1", received[:name]
        assert_equal new_content, received[:data]
        # Critical: original digest preserved for optimistic locking
        assert_equal "abc123", received[:digest]
        hosts_repo.verify
      end

      def test_cancelled_edit_returns_nil
        hosts = build_hosts

        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])

        editor_session = EditorSession.new(editor: build_noop_editor)
        service = EditHosts.new(hosts_repository: hosts_repo, editor_session: editor_session)

        assert_nil service.execute(node_name: "pve1")
        hosts_repo.verify
      end

      def test_no_changes_returns_nil
        hosts = build_hosts

        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])

        # editor leaves the file unchanged
        editor_session = EditorSession.new(editor: build_editor(ORIGINAL_HOSTS))
        service = EditHosts.new(hosts_repository: hosts_repo, editor_session: editor_session)

        assert_nil service.execute(node_name: "pve1")
        hosts_repo.verify
      end

      def test_dry_run_does_not_call_update
        hosts = build_hosts
        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])

        new_content = "#{ORIGINAL_HOSTS}10.0.0.1 newhost\n"
        editor_session = EditorSession.new(editor: build_editor(new_content))

        service = EditHosts.new(
          hosts_repository: hosts_repo,
          editor_session: editor_session,
          options: { dry_run: true }
        )
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert result.resource[:diff]
        assert_equal ORIGINAL_HOSTS, result.resource[:diff][:original]
        assert_equal new_content, result.resource[:diff][:edited]
        hosts_repo.verify
      end

      def test_api_error_surfaced_verbatim
        hosts = build_hosts
        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])
        hosts_repo.expect(:update, nil) do |_name, _data, _digest|
          raise StandardError, "permission denied"
        end

        new_content = "#{ORIGINAL_HOSTS}new\n"
        editor_session = EditorSession.new(editor: build_editor(new_content))

        service = EditHosts.new(hosts_repository: hosts_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/permission denied/, result.error)
        hosts_repo.verify
      end

      def test_digest_conflict_surfaced_verbatim
        hosts = build_hosts
        hosts_repo = Minitest::Mock.new
        hosts_repo.expect(:fetch, hosts, ["pve1"])
        # Proxmox returns the digest mismatch error verbatim
        hosts_repo.expect(:update, nil) do |_name, _data, _digest|
          raise StandardError,
                "wrong digest - file was modified concurrently"
        end

        new_content = "#{ORIGINAL_HOSTS}new\n"
        editor_session = EditorSession.new(editor: build_editor(new_content))

        service = EditHosts.new(hosts_repository: hosts_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/wrong digest/, result.error)
        assert_match(/concurrently/, result.error)
        hosts_repo.verify
      end
    end
  end
end
