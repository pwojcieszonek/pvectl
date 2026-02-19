# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class CloneVmTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_vm(attrs = {})
          defaults = { vmid: 100, name: "test-vm", node: "pve1", status: "stopped" }
          Models::Vm.new(defaults.merge(attrs))
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
          it "returns error when source VM not found" do
            vm_repo, task_repo = build_mocks
            vm_repo.expect(:get, nil, [999])

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 999)

            assert result.failed?
            assert_includes result.error, "999"
            vm_repo.verify
          end

          it "returns error for linked clone when VM is not a template" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(template: 0)
            vm_repo.expect(:get, vm, [100])

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, linked: true)

            assert result.failed?
            assert_includes result.error, "template"
            vm_repo.verify
          end

          it "allows linked clone when VM is a template" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(template: 1)
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200, linked: true)

            assert result.successful?
            vm_repo.verify
          end
        end

        # --- Auto-generation ---

        describe "auto-generation" do
          it "auto-generates name as source_name-clone when not provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(name: "web-server")
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            # Verify clone was called with auto-generated name
            clone_call = vm_repo.verify
            assert result.successful?
            assert_equal "web-server-clone", result.resource[:name]
          end

          it "auto-generates name as vm-vmid-clone when source has no name" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(name: nil)
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            assert_equal "vm-100-clone", result.resource[:name]
          end

          it "uses provided name when given" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200, name: "custom-name")

            assert result.successful?
            assert_equal "custom-name", result.resource[:name]
          end

          it "auto-selects VMID when not provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:next_available_vmid, 201)
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 201, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100)

            assert result.successful?
            assert_equal 201, result.resource[:new_vmid]
            vm_repo.verify
          end

          it "uses provided VMID when given" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            assert_equal 200, result.resource[:new_vmid]
            vm_repo.verify
          end
        end

        # --- Node handling ---

        describe "node handling" do
          it "uses source VM node when node not provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(node: "pve2")
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve2", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            vm_repo.verify
          end

          it "uses provided node when given" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(node: "pve1")
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve3", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200, node: "pve3")

            assert result.successful?
            vm_repo.verify
          end
        end

        # --- Clone options ---

        describe "clone options" do
          it "passes full: true by default (full clone)" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200)

            assert_equal true, clone_opts[:full]
          end

          it "passes full: false for linked clone" do
            vm_repo, task_repo = build_mocks
            vm = build_vm(template: 1)
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200, linked: true)

            assert_equal false, clone_opts[:full]
          end

          it "passes target when provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200, target_node: "pve2")

            assert_equal "pve2", clone_opts[:target]
          end

          it "passes storage when provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200, storage: "local-lvm")

            assert_equal "local-lvm", clone_opts[:storage]
          end

          it "passes pool when provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200, pool: "production")

            assert_equal "production", clone_opts[:pool]
          end

          it "passes description when provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            clone_opts = nil
            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone") do |vmid, node, new_vmid, opts|
              clone_opts = opts
              "UPID:pve1:clone"
            end
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            service.execute(vmid: 100, new_vmid: 200, description: "Cloned for testing")

            assert_equal "Cloned for testing", clone_opts[:description]
          end
        end

        # --- Sync/async modes ---

        describe "sync/async modes" do
          it "waits for task in sync mode and returns successful result" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task(exitstatus: "OK")

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            assert_equal task, result.task
            assert_equal :clone, result.operation
            task_repo.verify
          end

          it "returns pending result in async mode without waiting" do
            vm_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])

            service = CloneVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { async: true }
            )
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.pending?
            assert_equal "UPID:pve1:clone", result.task_upid
            assert_equal :clone, result.operation
            vm_repo.verify
          end

          it "returns failed result when task fails in sync mode" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task(exitstatus: "ERROR: clone failed")

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.failed?
            task_repo.verify
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed OperationResult" do
            vm_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, nil) do |*_args|
              raise StandardError, "API connection timeout"
            end

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.failed?
            assert_equal "API connection timeout", result.error
          end

          it "uses custom timeout when provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 600)

            service = CloneVm.new(
              vm_repository: vm_repo,
              task_repository: task_repo,
              options: { timeout: 600 }
            )
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            task_repo.verify
          end

          it "uses default timeout (300) when not provided" do
            vm_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:clone, "UPID:pve1:clone", [100, "pve1", 200, Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:clone"], timeout: 300)

            service = CloneVm.new(vm_repository: vm_repo, task_repository: task_repo)
            result = service.execute(vmid: 100, new_vmid: 200)

            assert result.successful?
            task_repo.verify
          end
        end
      end
    end
  end
end
