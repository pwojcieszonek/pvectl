# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class MoveDiskTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_vm(attrs = {})
          defaults = { vmid: 100, name: "test-vm", node: "pve1", status: "running" }
          Models::Vm.new(defaults.merge(attrs))
        end

        def build_container(attrs = {})
          defaults = { vmid: 200, name: "test-ct", node: "pve1", status: "running" }
          Models::Container.new(defaults.merge(attrs))
        end

        def build_task(attrs = {})
          defaults = { upid: "UPID:pve1:movedisk", status: "stopped", exitstatus: "OK" }
          Models::Task.new(defaults.merge(attrs))
        end

        def build_failed_task
          Models::Task.new(upid: "UPID:pve1:movedisk",
                           status: "stopped", exitstatus: "ERROR: bad disk")
        end

        def build_mocks
          [Minitest::Mock.new, Minitest::Mock.new, Minitest::Mock.new]
        end

        # --- VM async (default) ---

        describe "with VM async (default)" do
          it "returns pending result with UPID" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: false, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )

            result = service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            assert result.pending?
            assert_equal "UPID:pve1:movedisk", result.task_upid
            vm_repo.verify
          end
        end

        # --- VM sync (--wait) ---

        describe "with VM sync (--wait)" do
          it "waits for task and returns successful result" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: false, bwlimit: nil)
            task_repo.expect(:wait, task, ["UPID:pve1:movedisk"], timeout: 600)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true }
            )

            result = service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            assert result.successful?
            vm_repo.verify
            task_repo.verify
          end
        end

        # --- VM with format ---

        describe "with VM and format conversion" do
          it "passes format to repository" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: "qcow2", delete: false, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { format: "qcow2" }
            )

            service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            vm_repo.verify
          end
        end

        # --- VM with delete_source ---

        describe "with delete_source option" do
          it "propagates delete=true to repository" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: true, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { delete_source: true }
            )

            service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            vm_repo.verify
          end
        end

        # --- VM with bandwidth ---

        describe "with bandwidth option" do
          it "passes bwlimit in KiB/s" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: false, bwlimit: 10_240)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { bandwidth: 10_240 }
            )

            service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            vm_repo.verify
          end
        end

        # --- Container async (default) ---

        describe "with container async (default)" do
          it "calls move_volume and returns pending result" do
            vm_repo, container_repo, task_repo = build_mocks
            ct = build_container

            container_repo.expect(:move_volume, "UPID:pve1:movevol",
                                  [200, "pve1", "rootfs", "storage2"],
                                  delete: false, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )

            result = service.execute(:container, ct, disk: "rootfs", target_storage: "storage2")

            assert result.pending?
            assert_equal "UPID:pve1:movevol", result.task_upid
            container_repo.verify
          end
        end

        # --- Container does not pass format ---

        describe "with container and format option" do
          it "does not pass format to move_volume (LXC has no format param)" do
            vm_repo, container_repo, task_repo = build_mocks
            ct = build_container

            container_repo.expect(:move_volume, "UPID:pve1:movevol",
                                  [200, "pve1", "rootfs", "storage2"],
                                  delete: false, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { format: "qcow2" }
            )

            service.execute(:container, ct, disk: "rootfs", target_storage: "storage2")

            container_repo.verify
          end
        end

        # --- Container with delete_source ---

        describe "container with delete_source" do
          it "propagates delete=true to repository" do
            vm_repo, container_repo, task_repo = build_mocks
            ct = build_container

            container_repo.expect(:move_volume, "UPID:pve1:movevol",
                                  [200, "pve1", "mp0", "storage2"],
                                  delete: true, bwlimit: nil)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { delete_source: true }
            )

            service.execute(:container, ct, disk: "mp0", target_storage: "storage2")

            container_repo.verify
          end
        end

        # --- Failed task surfaced ---

        describe "with task failure (sync)" do
          it "returns failed result when task fails" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_failed_task

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: false, bwlimit: nil)
            task_repo.expect(:wait, task, ["UPID:pve1:movedisk"], timeout: 600)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true }
            )

            result = service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            assert result.failed?
            vm_repo.verify
            task_repo.verify
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed result" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:move_disk, nil) do |*_args, **_kwargs|
              raise StandardError, "Connection refused"
            end

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )

            result = service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            assert result.failed?
            assert_equal "Connection refused", result.error
          end
        end

        # --- Custom timeout ---

        describe "custom timeout" do
          it "uses custom timeout when provided" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:move_disk, "UPID:pve1:movedisk",
                           [100, "pve1", "scsi0", "storage2"],
                           format: nil, delete: false, bwlimit: nil)
            task_repo.expect(:wait, task, ["UPID:pve1:movedisk"], timeout: 300)

            service = MoveDisk.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true, timeout: 300 }
            )

            service.execute(:vm, vm, disk: "scsi0", target_storage: "storage2")

            task_repo.verify
          end
        end
      end
    end
  end
end
