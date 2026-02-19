# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class ResourceMigrationTest < Minitest::Test
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
          defaults = { upid: "UPID:pve1:migrate", status: "stopped", exitstatus: "OK" }
          Models::Task.new(defaults.merge(attrs))
        end

        def build_mocks
          [Minitest::Mock.new, Minitest::Mock.new, Minitest::Mock.new]
        end

        # --- VM migration (async default) ---

        describe "with VM async (default)" do
          it "returns pending result with UPID for single VM" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:migrate, "UPID:pve1:migrate", [100, "pve1", Hash])

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm], target: "pve2")

            assert_equal 1, results.size
            assert results.first.pending?
            assert_equal "UPID:pve1:migrate", results.first.task_upid
            vm_repo.verify
          end
        end

        # --- VM migration (sync --wait) ---

        describe "with VM sync (--wait)" do
          it "waits for task and returns successful result" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:migrate, "UPID:pve1:migrate", [100, "pve1", Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:migrate"], timeout: 600)

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true }
            )
            results = service.execute(:vm, [vm], target: "pve2")

            assert_equal 1, results.size
            assert results.first.successful?
            vm_repo.verify
            task_repo.verify
          end
        end

        # --- VM online migration auto-sets with-local-disks ---

        describe "VM online migration" do
          it "auto-sets with-local-disks when online is true" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            migrate_params = nil
            vm_repo.expect(:migrate, "UPID:pve1:migrate") do |vmid, node, params|
              migrate_params = params
              "UPID:pve1:migrate"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { online: true }
            )
            service.execute(:vm, [vm], target: "pve2")

            assert_equal 1, migrate_params[:"with-local-disks"]
            assert_equal 1, migrate_params[:online]
            vm_repo.verify
          end
        end

        # --- Container migration with --restart ---

        describe "with container restart" do
          it "passes restart parameter for container migration" do
            vm_repo, container_repo, task_repo = build_mocks
            ct = build_container

            migrate_params = nil
            container_repo.expect(:migrate, "UPID:pve1:migrate") do |ctid, node, params|
              migrate_params = params
              "UPID:pve1:migrate"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { restart: true }
            )
            service.execute(:container, [ct], target: "pve2")

            assert_equal 1, migrate_params[:restart]
            container_repo.verify
          end
        end

        # --- Container migration with --online ---

        describe "with container online" do
          it "passes online parameter for container migration" do
            vm_repo, container_repo, task_repo = build_mocks
            ct = build_container

            migrate_params = nil
            container_repo.expect(:migrate, "UPID:pve1:migrate") do |ctid, node, params|
              migrate_params = params
              "UPID:pve1:migrate"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { online: true }
            )
            service.execute(:container, [ct], target: "pve2")

            assert_equal 1, migrate_params[:online]
            assert_nil migrate_params[:"with-local-disks"]
            container_repo.verify
          end
        end

        # --- Batch migration ---

        describe "with multiple resources" do
          it "migrates all resources in batch" do
            vm_repo, container_repo, task_repo = build_mocks
            vm1 = build_vm(vmid: 100, node: "pve1")
            vm2 = build_vm(vmid: 101, node: "pve1")

            vm_repo.expect(:migrate, "UPID:pve1:migrate1", [100, "pve1", Hash])
            vm_repo.expect(:migrate, "UPID:pve1:migrate2", [101, "pve1", Hash])

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm1, vm2], target: "pve2")

            assert_equal 2, results.size
            assert results.all?(&:pending?)
            vm_repo.verify
          end
        end

        # --- partition_by_target: skip resources already on target ---

        describe "partition_by_target" do
          before do
            @original_stderr = $stderr
            $stderr = StringIO.new
          end

          after do
            $stderr = @original_stderr
          end

          it "skips resources already on target node" do
            vm_repo, container_repo, task_repo = build_mocks
            vm_on_source = build_vm(vmid: 100, node: "pve1")
            vm_on_target = build_vm(vmid: 101, node: "pve2")

            vm_repo.expect(:migrate, "UPID:pve1:migrate", [100, "pve1", Hash])

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm_on_source, vm_on_target], target: "pve2")

            assert_equal 1, results.size
            assert_includes $stderr.string, "101"
            vm_repo.verify
          end
        end

        # --- All resources on target ---

        describe "all resources on target" do
          before do
            @original_stderr = $stderr
            $stderr = StringIO.new
          end

          after do
            $stderr = @original_stderr
          end

          it "returns empty results when all resources already on target" do
            vm_repo, container_repo, task_repo = build_mocks
            vm1 = build_vm(vmid: 100, node: "pve2")
            vm2 = build_vm(vmid: 101, node: "pve2")

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm1, vm2], target: "pve2")

            assert_empty results
            assert_includes $stderr.string, "already on target node pve2"
          end
        end

        # --- fail_fast ---

        describe "fail_fast" do
          it "stops on first error with fail_fast option" do
            vm_repo, container_repo, task_repo = build_mocks
            vm1 = build_vm(vmid: 100, node: "pve1")
            vm2 = build_vm(vmid: 101, node: "pve1")

            vm_repo.expect(:migrate, nil) do |*_args|
              raise StandardError, "API error"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { fail_fast: true }
            )
            results = service.execute(:vm, [vm1, vm2], target: "pve2")

            assert_equal 1, results.size
            assert results.first.failed?
          end
        end

        # --- Error handling ---

        describe "error handling" do
          it "catches StandardError and returns failed result" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            vm_repo.expect(:migrate, nil) do |*_args|
              raise StandardError, "Connection refused"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo
            )
            results = service.execute(:vm, [vm], target: "pve2")

            assert_equal 1, results.size
            assert results.first.failed?
            assert_equal "Connection refused", results.first.error
          end
        end

        # --- target_storage passthrough ---

        describe "target_storage" do
          it "passes targetstorage parameter to repository" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm

            migrate_params = nil
            vm_repo.expect(:migrate, "UPID:pve1:migrate") do |vmid, node, params|
              migrate_params = params
              "UPID:pve1:migrate"
            end

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { target_storage: "local-lvm" }
            )
            service.execute(:vm, [vm], target: "pve2")

            assert_equal "local-lvm", migrate_params[:targetstorage]
            vm_repo.verify
          end
        end

        # --- Custom timeout ---

        describe "custom timeout" do
          it "uses custom timeout when provided" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:migrate, "UPID:pve1:migrate", [100, "pve1", Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:migrate"], timeout: 300)

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true, timeout: 300 }
            )
            results = service.execute(:vm, [vm], target: "pve2")

            assert results.first.successful?
            task_repo.verify
          end

          it "uses default timeout (600) when not provided" do
            vm_repo, container_repo, task_repo = build_mocks
            vm = build_vm
            task = build_task

            vm_repo.expect(:migrate, "UPID:pve1:migrate", [100, "pve1", Hash])
            task_repo.expect(:wait, task, ["UPID:pve1:migrate"], timeout: 600)

            service = ResourceMigration.new(
              vm_repository: vm_repo,
              container_repository: container_repo,
              task_repository: task_repo,
              options: { wait: true }
            )
            results = service.execute(:vm, [vm], target: "pve2")

            assert results.first.successful?
            task_repo.verify
          end
        end
      end
    end
  end
end
