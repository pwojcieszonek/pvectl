# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class ResourceDeleteTest < Minitest::Test
      describe "#execute" do
        describe "with VM" do
          it "deletes a stopped VM successfully" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
            task = Models::Task.new(upid: "UPID:pve1:abc", status: "stopped", exitstatus: "OK")

            vm_repo.expect(:delete, "UPID:pve1:abc", [100, "pve1"], destroy_disks: true, purge: false, force: false)
            task_repo.expect(:wait, task, ["UPID:pve1:abc"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm])

            assert_equal 1, results.size
            assert results.first.successful?
            assert_equal "OK", results.first.message
            vm_repo.verify
            task_repo.verify
          end

          it "returns error for running VM without force" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm])

            assert_equal 1, results.size
            assert results.first.failed?
            assert_includes results.first.error, "is running"
            assert_includes results.first.error, "--force"
          end

          it "stops and deletes running VM with force option" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "running")
            stop_task = Models::Task.new(upid: "UPID:pve1:stop", status: "stopped", exitstatus: "OK")
            delete_task = Models::Task.new(upid: "UPID:pve1:del", status: "stopped", exitstatus: "OK")

            vm_repo.expect(:stop, "UPID:pve1:stop", [100, "pve1"])
            task_repo.expect(:wait, stop_task, ["UPID:pve1:stop"], timeout: 60)
            vm_repo.expect(:delete, "UPID:pve1:del", [100, "pve1"], destroy_disks: true, purge: false, force: false)
            task_repo.expect(:wait, delete_task, ["UPID:pve1:del"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { force: true }
            )
            results = service.execute(:vm, [vm])

            assert_equal 1, results.size
            assert results.first.successful?
            vm_repo.verify
            task_repo.verify
          end

          it "passes keep_disks option to repository" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
            task = Models::Task.new(upid: "UPID:pve1:abc", status: "stopped", exitstatus: "OK")

            vm_repo.expect(:delete, "UPID:pve1:abc", [100, "pve1"], destroy_disks: false, purge: false, force: false)
            task_repo.expect(:wait, task, ["UPID:pve1:abc"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { keep_disks: true }
            )
            results = service.execute(:vm, [vm])

            assert results.first.successful?
            vm_repo.verify
          end

          it "passes purge option to repository" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")
            task = Models::Task.new(upid: "UPID:pve1:abc", status: "stopped", exitstatus: "OK")

            vm_repo.expect(:delete, "UPID:pve1:abc", [100, "pve1"], destroy_disks: true, purge: true, force: false)
            task_repo.expect(:wait, task, ["UPID:pve1:abc"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { purge: true }
            )
            results = service.execute(:vm, [vm])

            assert results.first.successful?
            vm_repo.verify
          end
        end

        describe "with container" do
          it "deletes a stopped container successfully" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            ct = Models::Container.new(vmid: 200, name: "test", node: "pve1", status: "stopped")
            task = Models::Task.new(upid: "UPID:pve1:abc", status: "stopped", exitstatus: "OK")

            container_repo.expect(:delete, "UPID:pve1:abc", [200, "pve1"], destroy_disks: true, purge: false, force: false)
            task_repo.expect(:wait, task, ["UPID:pve1:abc"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:container, [ct])

            assert_equal 1, results.size
            assert results.first.successful?
            container_repo.verify
            task_repo.verify
          end

          it "returns error for running container without force" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            ct = Models::Container.new(vmid: 200, name: "test", node: "pve1", status: "running")

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:container, [ct])

            assert_equal 1, results.size
            assert results.first.failed?
            assert_includes results.first.error, "is running"
          end
        end

        describe "with multiple resources" do
          it "continues on error by default" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm1 = Models::Vm.new(vmid: 100, name: "test1", node: "pve1", status: "running")
            vm2 = Models::Vm.new(vmid: 101, name: "test2", node: "pve1", status: "stopped")
            task = Models::Task.new(upid: "UPID:pve1:abc", status: "stopped", exitstatus: "OK")

            vm_repo.expect(:delete, "UPID:pve1:abc", [101, "pve1"], destroy_disks: true, purge: false, force: false)
            task_repo.expect(:wait, task, ["UPID:pve1:abc"], timeout: 60)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm1, vm2])

            assert_equal 2, results.size
            assert results[0].failed?
            assert results[1].successful?
          end

          it "stops on first error with fail_fast option" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm1 = Models::Vm.new(vmid: 100, name: "test1", node: "pve1", status: "running")
            vm2 = Models::Vm.new(vmid: 101, name: "test2", node: "pve1", status: "stopped")

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { fail_fast: true }
            )
            results = service.execute(:vm, [vm1, vm2])

            assert_equal 1, results.size
            assert results[0].failed?
          end
        end

        describe "async mode" do
          it "returns pending result without waiting" do
            vm_repo = Minitest::Mock.new
            container_repo = Minitest::Mock.new
            task_repo = Minitest::Mock.new

            vm = Models::Vm.new(vmid: 100, name: "test", node: "pve1", status: "stopped")

            vm_repo.expect(:delete, "UPID:pve1:abc", [100, "pve1"], destroy_disks: true, purge: false, force: false)

            service = ResourceDelete.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { async: true }
            )
            results = service.execute(:vm, [vm])

            assert_equal 1, results.size
            assert results.first.pending?
            assert_equal "UPID:pve1:abc", results.first.task_upid
            vm_repo.verify
          end
        end
      end
    end
  end
end
