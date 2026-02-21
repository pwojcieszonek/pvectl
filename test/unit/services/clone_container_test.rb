# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class CloneContainerTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_container(attrs = {})
          defaults = { vmid: 100, name: "test-ct", node: "pve1", status: "stopped" }
          Models::Container.new(defaults.merge(attrs))
        end

        def build_task(attrs = {})
          defaults = { upid: "UPID:pve1:clone", status: "stopped", exitstatus: "OK" }
          Models::Task.new(defaults.merge(attrs))
        end

        def build_mocks
          [Minitest::Mock.new, Minitest::Mock.new]
        end

        # --- Validation ---

        describe "validation" do
          it "returns error when source container not found" do
            ct_repo, task_repo = build_mocks
            ct_repo.expect(:get, nil, [999])

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 999)

            assert result.failed?
            assert_includes result.error, "999"
            ct_repo.verify
          end

          it "returns error for linked clone when container is not a template" do
            ct_repo, task_repo = build_mocks
            ct = build_container(template: 0)
            ct_repo.expect(:get, ct, [100])

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, linked: true)

            assert result.failed?
            assert_includes result.error, "template"
            ct_repo.verify
          end

          it "allows linked clone when container is a template" do
            ct_repo, task_repo = build_mocks
            ct = build_container(template: 1)
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, linked: true)

            assert result.successful?
            ct_repo.verify
          end
        end

        # --- Auto-generation ---

        describe "auto-generation" do
          it "auto-generates hostname as source_name-clone when not provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container(name: "web-server")
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            assert_equal "web-server-clone", result.resource[:hostname]
          end

          it "auto-generates hostname as ct-ctid-clone when source has no name" do
            ct_repo, task_repo = build_mocks
            ct = build_container(name: nil)
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            assert_equal "ct-100-clone", result.resource[:hostname]
          end

          it "uses provided hostname when given" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, hostname: "custom-name")

            assert result.successful?
            assert_equal "custom-name", result.resource[:hostname]
          end

          it "auto-selects CTID when not provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:next_available_ctid, 201)
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 201, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100)

            assert result.successful?
            assert_equal 201, result.resource[:new_ctid]
            ct_repo.verify
          end

          it "uses provided CTID when given" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            assert_equal 200, result.resource[:new_ctid]
            ct_repo.verify
          end
        end

        # --- Node handling ---

        describe "node handling" do
          it "uses source container node when node not provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container(node: "pve2")
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve2", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            assert_equal "pve2", result.resource[:node]
            ct_repo.verify
          end

          it "uses provided node when given" do
            ct_repo, task_repo = build_mocks
            ct = build_container(node: "pve1")
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve3", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, node: "pve3")

            assert result.successful?
            assert_equal "pve3", result.resource[:node]
            ct_repo.verify
          end

          it "uses target_node in resource_info when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container(node: "pve1")
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, target_node: "pve2")

            assert_equal "pve2", result.resource[:node]
            assert_equal "pve2", clone_opts[:target]
          end
        end

        # --- Clone options ---

        describe "clone options" do
          it "passes full: true by default (full clone)" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200)

            assert_equal true, clone_opts[:full]
          end

          it "passes full: false for linked clone" do
            ct_repo, task_repo = build_mocks
            ct = build_container(template: 1)
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, linked: true)

            assert_equal false, clone_opts[:full]
          end

          it "passes hostname in clone options" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, hostname: "my-clone")

            assert_equal "my-clone", clone_opts[:hostname]
          end

          it "passes target when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, target_node: "pve2")

            assert_equal "pve2", clone_opts[:target]
          end

          it "passes storage when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, storage: "local-lvm")

            assert_equal "local-lvm", clone_opts[:storage]
          end

          it "passes pool when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, pool: "production")

            assert_equal "production", clone_opts[:pool]
          end

          it "passes description when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            clone_opts = nil
            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone") do |ctid, node, new_ctid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 100, new_ctid: 200, description: "Cloned for testing")

            assert_equal "Cloned for testing", clone_opts[:description]
          end
        end

        # --- Sync/async modes ---

        describe "sync/async modes" do
          it "waits for task in sync mode and returns successful result" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task(exitstatus: "OK")

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            assert_equal task, result.task
            assert_equal :clone, result.operation
            task_repo.verify
          end

          it "returns pending result in async mode without waiting" do
            ct_repo, task_repo = build_mocks
            ct = build_container

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])

            service = CloneContainer.new(
              container_repository: ct_repo,
              task_repository: task_repo,
              options: { async: true }
            )
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.pending?
            assert_equal "UPID:pve1:clone", result.task_upid
            assert_equal :clone, result.operation
            ct_repo.verify
          end

          it "returns failed result when task fails in sync mode" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task(exitstatus: "ERROR: clone failed")

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.failed?
            task_repo.verify
          end
        end

        # --- Config params ---

        describe "with config_params" do
          it "updates container config after successful clone" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            update_params = nil
            ct_repo.expect(:update, nil) do |ctid, node, params|
              update_params = params
              true
            end

            config_params = { cores: 4, memory: 8192 }
            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, config_params: config_params)

            assert result.successful?
            assert_equal 4, update_params[:cores]
            assert_equal 8192, update_params[:memory]
            ct_repo.verify
          end

          it "returns partial success when config update fails" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)
            ct_repo.expect(:update, nil) do |*_args|
              raise StandardError, "API error: invalid parameter"
            end

            config_params = { cores: 4 }
            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, config_params: config_params)

            assert result.partial?
            assert_includes result.error, "Cloned successfully"
            assert_includes result.error, "config update failed"
            assert_includes result.error, "API error: invalid parameter"
          end

          it "skips config update when config_params is empty" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, config_params: {})

            assert result.successful?
            ct_repo.verify
          end

          it "uses target node for config update on cross-node clone" do
            ct_repo, task_repo = build_mocks
            ct = build_container(node: "pve1")
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            update_node = nil
            ct_repo.expect(:update, nil) do |ctid, node, params|
              update_node = node
              true
            end

            config_params = { cores: 2 }
            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200, target_node: "pve2",
                                     config_params: config_params)

            assert result.successful?
            assert_equal "pve2", update_node
          end

          it "does not start container when config update fails" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)
            ct_repo.expect(:update, nil) do |*_args|
              raise StandardError, "config error"
            end

            config_params = { cores: 4 }
            service = CloneContainer.new(
              container_repository: ct_repo, task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(ctid: 100, new_ctid: 200, config_params: config_params)

            assert result.partial?
            # ct_repo.verify ensures no unexpected calls (like start) were made
            ct_repo.verify
          end

          it "starts container after config update when --start set" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task
            start_task = build_task(upid: "UPID:pve1:start")

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)
            ct_repo.expect(:update, nil, [200, "pve1", Hash])
            ct_repo.expect(:start, "UPID:pve1:start", [200, "pve1"])
            task_repo.expect(:wait, start_task, ["UPID:pve1:start"], timeout: 60)

            config_params = { cores: 4 }
            service = CloneContainer.new(
              container_repository: ct_repo, task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(ctid: 100, new_ctid: 200, config_params: config_params)

            assert result.successful?
            ct_repo.verify
            task_repo.verify
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed ContainerOperationResult" do
            ct_repo, task_repo = build_mocks
            ct = build_container

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, nil) do |*_args|
              raise StandardError, "API connection timeout"
            end

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.failed?
            assert_equal "API connection timeout", result.error
          end

          it "uses custom timeout when provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 600)

            service = CloneContainer.new(
              container_repository: ct_repo,
              task_repository: task_repo,
              options: { timeout: 600 }
            )
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            task_repo.verify
          end

          it "uses default timeout (300) when not provided" do
            ct_repo, task_repo = build_mocks
            ct = build_container
            task = build_task

            ct_repo.expect(:get, ct, [100])
            ct_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 100, new_ctid: 200)

            assert result.successful?
            task_repo.verify
          end
        end
      end
    end
  end
end
