# frozen_string_literal: true

require "test_helper"

class ServicesVmLifecycleTest < Minitest::Test
  def setup
    @vm = Pvectl::Models::Vm.new(vmid: 100, name: "test-vm", node: "pve1", status: "stopped")
    @running_vm = Pvectl::Models::Vm.new(vmid: 101, name: "running-vm", node: "pve1", status: "running")
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Services::VmLifecycle
  end

  # ---------------------------
  # execute - single VM
  # ---------------------------

  def test_execute_start_returns_operation_result
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@vm])

    assert_equal 1, results.length
    assert_instance_of Pvectl::Models::VmOperationResult, results.first
    assert results.first.successful?
  end

  def test_execute_returns_failed_result_on_api_error
    service = create_service_with_error("Permission denied")

    results = service.execute(:start, [@vm])

    assert_equal 1, results.length
    assert results.first.failed?
    assert_equal "Permission denied", results.first.error
  end

  # ---------------------------
  # Sync vs Async
  # ---------------------------

  def test_start_is_sync_by_default
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@vm])

    # Sync means we waited for task - result has task object
    assert results.first.task
    assert results.first.successful?
  end

  def test_shutdown_is_async_by_default
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      skip_wait: true
    )

    results = service.execute(:shutdown, [@running_vm])

    # Async means we didn't wait - result has task_upid but no task
    assert_nil results.first.task
    assert_equal "UPID:pve1:ABC", results.first.task_upid
    assert results.first.pending?
  end

  def test_async_flag_forces_async_mode
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      skip_wait: true,
      options: { async: true }
    )

    results = service.execute(:start, [@vm])

    # Even start should be async with flag
    assert results.first.pending?
  end

  def test_wait_flag_forces_sync_mode
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK",
      options: { wait: true }
    )

    results = service.execute(:shutdown, [@running_vm])

    # Even shutdown should be sync with flag
    assert results.first.successful?
    assert results.first.task
  end

  # ---------------------------
  # Multiple VMs
  # ---------------------------

  def test_execute_multiple_vms_returns_multiple_results
    vm2 = Pvectl::Models::Vm.new(vmid: 102, name: "test-vm-2", node: "pve1", status: "stopped")
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@vm, vm2])

    assert_equal 2, results.length
    assert results.all?(&:successful?)
  end

  def test_fail_fast_stops_on_first_error
    vm2 = Pvectl::Models::Vm.new(vmid: 102, name: "test-vm-2", node: "pve1", status: "stopped")
    service = create_service_with_error_on_second(
      options: { fail_fast: true }
    )

    results = service.execute(:start, [@vm, vm2])

    # Should have 2 results - first success, second fail
    assert_equal 2, results.length
    assert results.first.successful?
    assert results.last.failed?
  end

  private

  def create_service_with_mocks(task_upid:, task_status: nil, task_exitstatus: nil, skip_wait: false, options: {})
    vm_repo = MockVmRepo.new(task_upid)
    task_repo = MockTaskRepo.new(task_status, task_exitstatus, skip_wait)
    Pvectl::Services::VmLifecycle.new(vm_repo, task_repo, options)
  end

  def create_service_with_error(message)
    vm_repo = MockVmRepoWithError.new(message)
    task_repo = MockTaskRepo.new(nil, nil, true)
    Pvectl::Services::VmLifecycle.new(vm_repo, task_repo, {})
  end

  def create_service_with_error_on_second(options:)
    vm_repo = MockVmRepoErrorOnSecond.new
    task_repo = MockTaskRepo.new("stopped", "OK", false)
    Pvectl::Services::VmLifecycle.new(vm_repo, task_repo, options)
  end

  class MockVmRepo
    def initialize(task_upid)
      @task_upid = task_upid
    end

    def start(vmid, node) = @task_upid
    def stop(vmid, node) = @task_upid
    def shutdown(vmid, node) = @task_upid
    def restart(vmid, node) = @task_upid
    def reset(vmid, node) = @task_upid
    def suspend(vmid, node) = @task_upid
    def resume(vmid, node) = @task_upid
  end

  class MockVmRepoWithError
    def initialize(message)
      @message = message
    end

    def start(vmid, node) = raise(StandardError, @message)
    def stop(vmid, node) = raise(StandardError, @message)
    def shutdown(vmid, node) = raise(StandardError, @message)
    def restart(vmid, node) = raise(StandardError, @message)
    def reset(vmid, node) = raise(StandardError, @message)
    def suspend(vmid, node) = raise(StandardError, @message)
    def resume(vmid, node) = raise(StandardError, @message)
  end

  class MockVmRepoErrorOnSecond
    def initialize
      @call_count = 0
    end

    def start(vmid, node)
      @call_count += 1
      raise StandardError, "Second VM error" if @call_count > 1
      "UPID:pve1:ABC"
    end
  end

  class MockTaskRepo
    def initialize(status, exitstatus, skip_wait)
      @status = status
      @exitstatus = exitstatus
      @skip_wait = skip_wait
    end

    def find(upid)
      Pvectl::Models::Task.new(
        upid: upid,
        status: @status || "running",
        exitstatus: @exitstatus
      )
    end

    def wait(upid, timeout:)
      return nil if @skip_wait
      Pvectl::Models::Task.new(
        upid: upid,
        status: @status,
        exitstatus: @exitstatus
      )
    end
  end
end
