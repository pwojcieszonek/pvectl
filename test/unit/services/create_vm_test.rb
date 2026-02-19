# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class CreateVmTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_task(attrs = {})
          defaults = { upid: "UPID:pve1:create", status: "stopped", exitstatus: "OK" }
          Models::Task.new(defaults.merge(attrs))
        end

        def build_mocks
          [Minitest::Mock.new, Minitest::Mock.new]
        end

        # --- Auto-VMID ---

        describe "auto-VMID" do
          it "uses next_available_vmid when vmid not provided" do
            vm_repo, task_repo = build_mocks
            task = build_task

            vm_repo.expect(:next_available_vmid, 100)
            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(name: "test-vm", node: "pve1")

            assert result.successful?
            assert_equal 100, result.resource[:vmid]
            vm_repo.verify
          end

          it "uses provided vmid" do
            vm_repo, task_repo = build_mocks
            task = build_task

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 200, name: "test-vm", node: "pve1")

            assert result.successful?
            assert_equal 200, result.resource[:vmid]
            vm_repo.verify
          end

          it "populates vm model for presenter compatibility" do
            vm_repo, task_repo = build_mocks
            task = build_task

            vm_repo.expect(:next_available_vmid, 100)
            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(name: "test-vm", node: "pve1")

            assert_instance_of Models::Vm, result.vm
            assert_equal 100, result.vm.vmid
            assert_equal "test-vm", result.vm.name
            assert_equal "pve1", result.vm.node
          end
        end

        # --- Parameter building ---

        describe "parameter building" do
          it "builds params with CPU, memory, and basic options" do
            vm_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            vm_repo.expect(:create, "UPID:pve1:create") do |node, vmid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(
              vmid: 100, name: "web", node: "pve1",
              cores: 4, sockets: 2, memory: 8192, ostype: "l26"
            )

            assert_equal "web", created_params[:name]
            assert_equal 4, created_params[:cores]
            assert_equal 2, created_params[:sockets]
            assert_equal 8192, created_params[:memory]
            assert_equal "l26", created_params[:ostype]
          end

          it "maps disk configs to scsi0, scsi1, etc." do
            vm_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            vm_repo.expect(:create, "UPID:pve1:create") do |_node, _vmid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            disks = [
              { storage: "local-lvm", size: "32G" },
              { storage: "ceph", size: "100G", format: "qcow2" }
            ]

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, name: "web", node: "pve1", disks: disks)

            assert_equal "local-lvm:32,format=raw", created_params[:scsi0]
            assert_equal "ceph:100,format=qcow2", created_params[:scsi1]
          end

          it "maps net configs to net0, net1, etc." do
            vm_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            vm_repo.expect(:create, "UPID:pve1:create") do |_node, _vmid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            nets = [
              { bridge: "vmbr0", model: "virtio", tag: "100" },
              { bridge: "vmbr1" }
            ]

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, name: "web", node: "pve1", nets: nets)

            assert_equal "virtio,bridge=vmbr0,tag=100", created_params[:net0]
            assert_equal "virtio,bridge=vmbr1", created_params[:net1]
          end

          it "includes scsihw parameter" do
            vm_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            vm_repo.expect(:create, "UPID:pve1:create") do |_node, _vmid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, name: "web", node: "pve1", scsihw: "virtio-scsi-pci")

            assert_equal "virtio-scsi-pci", created_params[:scsihw]
          end

          it "includes cloud-init params" do
            vm_repo, task_repo = build_mocks
            task = build_task
            created_params = nil

            vm_repo.expect(:create, "UPID:pve1:create") do |_node, _vmid, params|
              created_params = params
              "UPID:pve1:create"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            cloud_init = { ciuser: "admin", cipassword: "secret", ipconfig0: "ip=dhcp" }

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, name: "web", node: "pve1", cloud_init: cloud_init)

            assert_equal "admin", created_params[:ciuser]
            assert_equal "secret", created_params[:cipassword]
            assert_equal "ip=dhcp", created_params[:ipconfig0]
          end
        end

        # --- Sync/async modes ---

        describe "sync/async modes" do
          it "waits for task in sync mode" do
            vm_repo, task_repo = build_mocks
            task = build_task

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.successful?
            assert_equal task, result.task
            assert_equal :create, result.operation
            task_repo.verify
          end

          it "returns pending in async mode" do
            vm_repo, task_repo = build_mocks

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])

            service = CreateVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { async: true }
            )
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.pending?
            assert_equal "UPID:pve1:create", result.task_upid
            assert_equal :create, result.operation
            vm_repo.verify
          end

          it "returns failed result when task fails" do
            vm_repo, task_repo = build_mocks
            task = build_task(exitstatus: "ERROR: creation failed")

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.failed?
          end
        end

        # --- Auto-start ---

        describe "auto-start" do
          it "starts VM after successful creation when start option is true" do
            vm_repo, task_repo = build_mocks
            create_task = build_task
            start_task = build_task(upid: "UPID:pve1:start")

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, create_task, ["UPID:pve1:create"], timeout: 300)
            vm_repo.expect(:start, "UPID:pve1:start", [100, "pve1"])
            task_repo.expect(:wait, start_task, ["UPID:pve1:start"], timeout: 60)

            service = CreateVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.successful?
            vm_repo.verify
            task_repo.verify
          end

          it "does not start VM when creation fails" do
            vm_repo, task_repo = build_mocks
            task = build_task(exitstatus: "ERROR: failed")

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 300)

            service = CreateVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { start: true }
            )
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.failed?
            vm_repo.verify
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed result" do
            vm_repo, task_repo = build_mocks

            vm_repo.expect(:create, nil) do |*_args|
              raise StandardError, "API connection timeout"
            end

            service = CreateVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.failed?
            assert_equal "API connection timeout", result.error
          end

          it "uses custom timeout when provided" do
            vm_repo, task_repo = build_mocks
            task = build_task

            vm_repo.expect(:create, "UPID:pve1:create", ["pve1", 100, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:create"], timeout: 600)

            service = CreateVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { timeout: 600 }
            )
            result = service.execute(vmid: 100, name: "web", node: "pve1")

            assert result.successful?
            task_repo.verify
          end
        end
      end
    end
  end
end
