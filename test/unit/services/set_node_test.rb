# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SetNodeTest < Minitest::Test
      def build_node(attrs = {})
        Models::Node.new({ name: "pve1", status: "online" }.merge(attrs))
      end

      def build_config(extras = {})
        { description: "production node", digest: "abc123" }.merge(extras)
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

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { description: "updated" })

        assert result.successful?
        assert_equal :set, result.operation
        assert_kind_of Models::NodeOperationResult, result
        assert_equal "updated", update_params[:description]
        assert_equal "abc123", update_params[:digest]
        node_repo.verify
      end

      def test_dry_run_does_not_call_api
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        service = SetNode.new(node_repository: node_repo, options: { dry_run: true })
        result = service.execute(node_name: "pve1", params: { description: "new" })

        assert result.successful?
        assert result.resource[:diff]
        node_repo.verify
      end

      def test_no_changes_returns_nil
        node = build_node
        config = build_config

        node_repo = Minitest::Mock.new
        node_repo.expect(:get, node, ["pve1"])
        node_repo.expect(:fetch_config, config, ["pve1"])

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { description: "production node" })

        assert_nil result
        node_repo.verify
      end

      def test_node_not_found
        node_repo = Minitest::Mock.new
        node_repo.expect(:get, nil, ["pve1"])

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { description: "test" })

        assert result.failed?
        assert_match(/not found/, result.error)
        assert_kind_of Models::NodeOperationResult, result
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

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { description: "new" })

        assert result.failed?
        assert_match(/permission denied/, result.error)
        node_repo.verify
      end

      def test_adds_new_key
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

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { wakeonlan: "00:11:22:33:44:55" })

        assert result.successful?
        assert_equal "00:11:22:33:44:55", update_params[:wakeonlan]
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

        service = SetNode.new(node_repository: node_repo)
        result = service.execute(node_name: "pve1", params: { description: "updated", wakeonlan: "00:11:22:33:44:55" })

        diff = result.resource[:diff]
        assert_includes diff[:changed].keys, :description
        assert_includes diff[:added].keys, :wakeonlan
        node_repo.verify
      end
    end
  end
end
