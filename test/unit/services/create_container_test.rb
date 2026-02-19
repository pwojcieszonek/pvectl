# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class CreateContainerTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_task(attrs = {})
          defaults = { upid: "UPID:pve1:create", status: "stopped", exitstatus: "OK" }
          Models::Task.new(defaults.merge(attrs))
        end

        def build_mocks
          [Minitest::Mock.new, Minitest::Mock.new]
        end

        # --- Auto-CTID ---

        describe "auto-CTID" do
          it "uses next_available_ctid when ctid not provided" do
            ct_repo, task_repo = build_mocks
            task = build_task

            ct_repo.expect(:next_available_ctid, 200)
            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(hostname: "web-ct", node: "pve1", ostemplate: "local:vztmpl/debian-12.tar.zst")

            assert result.successful?
            assert_equal 200, result.resource[:ctid]
            ct_repo.verify
          end

          it "uses provided ctid" do
            ct_repo, task_repo = build_mocks
            task = build_task

            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 300, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 300, hostname: "web-ct", node: "pve1", ostemplate: "local:vztmpl/debian-12.tar.zst")

            assert result.successful?
            assert_equal 300, result.resource[:ctid]
          end

          it "populates container model for presenter compatibility" do
            ct_repo, task_repo = build_mocks
            task = build_task

            ct_repo.expect(:next_available_ctid, 200)
            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(hostname: "web-ct", node: "pve1", ostemplate: "local:vztmpl/debian-12.tar.zst")

            assert_instance_of Models::Container, result.container
            assert_equal 200, result.container.vmid
            assert_equal "web-ct", result.container.name
            assert_equal "pve1", result.container.node
          end
        end

        # --- Parameter building ---

        describe "parameter building" do
          it "builds params with hostname, ostemplate, and basic options" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |node, ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(
              ctid: 200, hostname: "web-ct", node: "pve1",
              ostemplate: "local:vztmpl/debian-12.tar.zst",
              cores: 2, memory: 2048, swap: 512
            )

            assert_equal "web-ct", created_params[:hostname]
            assert_equal "local:vztmpl/debian-12.tar.zst", created_params[:ostemplate]
            assert_equal 2, created_params[:cores]
            assert_equal 2048, created_params[:memory]
            assert_equal 512, created_params[:swap]
          end

          it "sets unprivileged to 1 by default" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert_equal 1, created_params[:unprivileged]
          end

          it "sets unprivileged to 0 when privileged flag is true" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t", privileged: true)

            assert_equal 0, created_params[:unprivileged]
          end

          it "maps rootfs config to proxmox format" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            rootfs = { storage: "local-lvm", size: "8G" }

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t", rootfs: rootfs)

            assert_equal "local-lvm:8", created_params[:rootfs]
          end

          it "maps mountpoints to mp0, mp1, etc." do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            mps = [
              { storage: "local-lvm", size: "32G", mp: "/mnt/data" },
              { storage: "ceph", size: "10G", mp: "/mnt/logs" }
            ]

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t", mountpoints: mps)

            assert_equal "local-lvm:32,mp=/mnt/data", created_params[:mp0]
            assert_equal "ceph:10,mp=/mnt/logs", created_params[:mp1]
          end

          it "maps net configs to net0, net1, etc." do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            nets = [
              { bridge: "vmbr0", name: "eth0", ip: "dhcp" },
              { bridge: "vmbr1" }
            ]

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t", nets: nets)

            assert_equal "name=eth0,bridge=vmbr0,ip=dhcp,type=veth", created_params[:net0]
            assert_equal "name=eth0,bridge=vmbr1,type=veth", created_params[:net1]
          end

          it "includes password and ssh-public-keys" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(
              ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t",
              password: "secret123", ssh_public_keys: "ssh-rsa AAAA..."
            )

            assert_equal "secret123", created_params[:password]
            assert_equal "ssh-rsa AAAA...", created_params[:"ssh-public-keys"]
          end

          it "includes features string" do
            ct_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            ct_repo.expect(:create, "UPID:pve1:create") do |_node, _ctid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t", features: "nesting=1,keyctl=1")

            assert_equal "nesting=1,keyctl=1", created_params[:features]
          end
        end

        # --- Sync/async modes ---

        describe "sync/async modes" do
          it "waits for task in sync mode" do
            ct_repo, task_repo = build_mocks
            task = build_task

            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert result.successful?
            assert_equal :create, result.operation
          end

          it "returns pending in async mode" do
            ct_repo, task_repo = build_mocks

            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])

            service = CreateContainer.new(
              container_repository: ct_repo,
              task_repository: task_repo,
              options: { async: true }
            )
            result = service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert result.pending?
            assert_equal "UPID:pve1:create", result.task_upid
          end
        end

        # --- Auto-start ---

        describe "auto-start" do
          it "starts container after successful creation" do
            ct_repo, task_repo = build_mocks
            create_task = build_task
            start_task = build_task(upid: "UPID:pve1:start")

            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, create_task, ["UPID:pve1:create"], timeout: 300)
            ct_repo.expect(:start, "UPID:pve1:start", [200, "pve1"])
            task_repo.expect(:wait, start_task, ["UPID:pve1:start"], timeout: 60)

            service = CreateContainer.new(
              container_repository: ct_repo,
              task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert result.successful?
            ct_repo.verify
            task_repo.verify
          end

          it "does not start when creation fails" do
            ct_repo, task_repo = build_mocks
            task = build_task(exitstatus: "ERROR: failed")

            ct_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateContainer.new(
              container_repository: ct_repo,
              task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert result.failed?
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed result" do
            ct_repo, task_repo = build_mocks

            ct_repo.expect(:create, nil) do |*_args|
              raise StandardError, "API connection timeout"
            end

            service = CreateContainer.new(container_repository: ct_repo, task_repository: task_repo)
            result = service.execute(ctid: 200, hostname: "ct", node: "pve1", ostemplate: "t")

            assert result.failed?
            assert_equal "API connection timeout", result.error
          end
        end
      end
    end
  end
end
