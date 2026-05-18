# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditDnsTest < Minitest::Test
      def build_dns(attrs = {})
        Models::DnsConfig.new({ node: "pve1", search: "example.com", dns1: "8.8.8.8" }.merge(attrs))
      end

      def build_editor(new_content)
        ->(path) { File.write(path, new_content) }
      end

      def build_noop_editor
        ->(_path) {}
      end

      def to_editable_yaml(dns)
        { "search" => dns.search, "dns1" => dns.dns1, "dns2" => dns.dns2, "dns3" => dns.dns3 }
          .compact.to_yaml
      end

      def test_applies_changes_to_api
        dns = build_dns

        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])

        update_params = nil
        dns_repo.expect(:update, nil) do |name, params|
          update_params = params
          name == "pve1"
        end

        edited_yaml = { "search" => "new.example.com", "dns1" => "8.8.4.4" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert_kind_of Models::NodeOperationResult, result
        assert_equal :edit, result.operation
        assert_equal "new.example.com", update_params[:search]
        assert_equal "8.8.4.4", update_params[:dns1]
        dns_repo.verify
      end

      def test_cancelled_edit_returns_nil
        dns = build_dns

        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])

        editor_session = EditorSession.new(editor: build_noop_editor)
        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session)

        assert_nil service.execute(node_name: "pve1")
        dns_repo.verify
      end

      def test_no_changes_returns_nil
        dns = build_dns
        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])

        same_yaml = to_editable_yaml(dns)
        editor_session = EditorSession.new(editor: build_editor(same_yaml))

        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session)
        assert_nil service.execute(node_name: "pve1")
        dns_repo.verify
      end

      def test_dry_run_does_not_call_update
        dns = build_dns
        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])

        edited_yaml = { "search" => "new.example.com", "dns1" => "8.8.8.8" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session, options: { dry_run: true })
        result = service.execute(node_name: "pve1")

        assert result.successful?
        assert result.resource[:diff]
        dns_repo.verify
      end

      def test_api_error_returns_failed_result
        dns = build_dns
        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])
        dns_repo.expect(:update, nil) { |_name, _params| raise StandardError, "permission denied" }

        edited_yaml = { "search" => "x", "dns1" => "8.8.8.8" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/permission denied/, result.error)
        dns_repo.verify
      end

      def test_search_required_validation
        dns = build_dns
        dns_repo = Minitest::Mock.new
        dns_repo.expect(:fetch, dns, ["pve1"])

        # Remove search field — PUT requires search
        edited_yaml = { "dns1" => "8.8.8.8" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditDns.new(dns_repository: dns_repo, editor_session: editor_session)
        result = service.execute(node_name: "pve1")

        assert result.failed?
        assert_match(/search/i, result.error)
        dns_repo.verify
      end
    end
  end
end
