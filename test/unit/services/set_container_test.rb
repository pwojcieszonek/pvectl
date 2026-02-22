# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SetContainerTest < Minitest::Test
      def build_container(attrs = {})
        Models::Container.new({ vmid: 200, name: "test-ct", node: "pve1", status: "running" }.merge(attrs))
      end

      def build_config(extras = {})
        { memory: "4096", cores: "2", name: "test-ct", digest: "abc123" }.merge(extras)
      end

      def test_applies_changes_to_api
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])

        update_params = nil
        ct_repo.expect(:update, nil) do |ctid, node, params|
          update_params = params
          true
        end

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "8192" })

        assert result.successful?
        assert_equal :set, result.operation
        assert_kind_of Models::ContainerOperationResult, result
        assert_equal "8192", update_params[:memory]
        assert_equal "abc123", update_params[:digest]
        ct_repo.verify
      end

      def test_multiple_changes
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])

        update_params = nil
        ct_repo.expect(:update, nil) do |ctid, node, params|
          update_params = params
          true
        end

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "8192", cores: "4" })

        assert result.successful?
        assert_equal "8192", update_params[:memory]
        assert_equal "4", update_params[:cores]
        ct_repo.verify
      end

      def test_adds_new_key
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])

        update_params = nil
        ct_repo.expect(:update, nil) do |ctid, node, params|
          update_params = params
          true
        end

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { description: "new desc" })

        assert result.successful?
        assert_equal "new desc", update_params[:description]
        ct_repo.verify
      end

      def test_dry_run_does_not_call_api
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])
        # NO update expectation — dry run should NOT call update

        service = SetContainer.new(container_repository: ct_repo, options: { dry_run: true })
        result = service.execute(ctid: 200, params: { memory: "8192" })

        assert result.successful?
        assert result.resource[:diff]
        refute_empty result.resource[:diff][:changed]
        ct_repo.verify
      end

      def test_no_changes_returns_nil
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "4096" })

        assert_nil result
        ct_repo.verify
      end

      def test_container_not_found
        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, nil, [200])

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "8192" })

        assert result.failed?
        assert_match(/not found/, result.error)
        assert_kind_of Models::ContainerOperationResult, result
        ct_repo.verify
      end

      def test_api_error
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])
        ct_repo.expect(:update, nil) do |_ctid, _node, _params|
          raise StandardError, "API timeout"
        end

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "8192" })

        assert result.failed?
        assert_match(/API timeout/, result.error)
        ct_repo.verify
      end

      def test_diff_contains_changes
        ct = build_container
        config = build_config

        ct_repo = Minitest::Mock.new
        ct_repo.expect(:get, ct, [200])
        ct_repo.expect(:fetch_config, config, ["pve1", 200])

        _update_params = nil
        ct_repo.expect(:update, nil) do |ctid, node, params|
          _update_params = params
          true
        end

        service = SetContainer.new(container_repository: ct_repo)
        result = service.execute(ctid: 200, params: { memory: "8192", description: "new" })

        diff = result.resource[:diff]
        assert_includes diff[:changed].keys, :memory
        assert_includes diff[:added].keys, :description
        ct_repo.verify
      end
    end
  end
end
