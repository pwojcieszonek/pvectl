# frozen_string_literal: true

require "test_helper"

class ServicesContainerLifecycleTest < Minitest::Test
  def setup
    @ct = Pvectl::Models::Container.new(vmid: 200, name: "test-ct", node: "pve1", status: "stopped")
    @running_ct = Pvectl::Models::Container.new(vmid: 201, name: "running-ct", node: "pve1", status: "running")
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Services::ContainerLifecycle
  end

  # ---------------------------
  # execute - single container
  # ---------------------------

  def test_execute_start_returns_container_operation_result
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@ct])

    assert_equal 1, results.length
    assert_instance_of Pvectl::Models::ContainerOperationResult, results.first
    assert results.first.successful?
  end

  def test_execute_returns_failed_result_on_api_error
    service = create_service_with_error("Permission denied")

    results = service.execute(:start, [@ct])

    assert_equal 1, results.length
    assert results.first.failed?
    assert_equal "Permission denied", results.first.error
  end

  def test_result_has_container_reference
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@ct])

    assert_equal @ct, results.first.container
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

    results = service.execute(:start, [@ct])

    assert results.first.task
    assert results.first.successful?
  end

  def test_shutdown_is_async_by_default
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      skip_wait: true
    )

    results = service.execute(:shutdown, [@running_ct])

    assert_nil results.first.task
    assert_equal "UPID:pve1:ABC", results.first.task_upid
    assert results.first.pending?
  end

  def test_restart_is_async_by_default
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      skip_wait: true
    )

    results = service.execute(:restart, [@running_ct])

    assert results.first.pending?
  end

  def test_async_flag_forces_async_mode
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      skip_wait: true,
      options: { async: true }
    )

    results = service.execute(:start, [@ct])

    assert results.first.pending?
  end

  def test_wait_flag_forces_sync_mode
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK",
      options: { wait: true }
    )

    results = service.execute(:shutdown, [@running_ct])

    assert results.first.successful?
    assert results.first.task
  end

  # ---------------------------
  # Multiple containers
  # ---------------------------

  def test_execute_multiple_containers_returns_multiple_results
    ct2 = Pvectl::Models::Container.new(vmid: 202, name: "test-ct-2", node: "pve1", status: "stopped")
    service = create_service_with_mocks(
      task_upid: "UPID:pve1:ABC",
      task_status: "stopped",
      task_exitstatus: "OK"
    )

    results = service.execute(:start, [@ct, ct2])

    assert_equal 2, results.length
    assert results.all?(&:successful?)
  end

  def test_fail_fast_stops_on_first_error
    ct2 = Pvectl::Models::Container.new(vmid: 202, name: "test-ct-2", node: "pve1", status: "stopped")
    service = create_service_with_error_on_second(
      options: { fail_fast: true }
    )

    results = service.execute(:start, [@ct, ct2])

    assert_equal 2, results.length
    assert results.first.successful?
    assert results.last.failed?
  end

  # ---------------------------
  # Validation
  # ---------------------------

  def test_rejects_unsupported_operation
    service = create_service_with_mocks(task_upid: "UPID:pve1:ABC", skip_wait: true)

    assert_raises(ArgumentError) { service.execute(:reset, [@ct]) }
  end

  def test_rejects_suspend_operation
    service = create_service_with_mocks(task_upid: "UPID:pve1:ABC", skip_wait: true)

    assert_raises(ArgumentError) { service.execute(:suspend, [@ct]) }
  end

  def test_rejects_resume_operation
    service = create_service_with_mocks(task_upid: "UPID:pve1:ABC", skip_wait: true)

    assert_raises(ArgumentError) { service.execute(:resume, [@ct]) }
  end

  private

  def create_service_with_mocks(task_upid:, task_status: nil, task_exitstatus: nil, skip_wait: false, options: {})
    ct_repo = MockContainerRepo.new(task_upid)
    task_repo = MockTaskRepo.new(task_status, task_exitstatus, skip_wait)
    Pvectl::Services::ContainerLifecycle.new(ct_repo, task_repo, options)
  end

  def create_service_with_error(message)
    ct_repo = MockContainerRepoWithError.new(message)
    task_repo = MockTaskRepo.new(nil, nil, true)
    Pvectl::Services::ContainerLifecycle.new(ct_repo, task_repo, {})
  end

  def create_service_with_error_on_second(options:)
    ct_repo = MockContainerRepoErrorOnSecond.new
    task_repo = MockTaskRepo.new("stopped", "OK", false)
    Pvectl::Services::ContainerLifecycle.new(ct_repo, task_repo, options)
  end

  class MockContainerRepo
    def initialize(task_upid)
      @task_upid = task_upid
    end

    def start(ctid, node) = @task_upid
    def stop(ctid, node) = @task_upid
    def shutdown(ctid, node) = @task_upid
    def restart(ctid, node) = @task_upid
  end

  class MockContainerRepoWithError
    def initialize(message)
      @message = message
    end

    def start(ctid, node) = raise(StandardError, @message)
    def stop(ctid, node) = raise(StandardError, @message)
    def shutdown(ctid, node) = raise(StandardError, @message)
    def restart(ctid, node) = raise(StandardError, @message)
  end

  class MockContainerRepoErrorOnSecond
    def initialize
      @call_count = 0
    end

    def start(ctid, node)
      @call_count += 1
      raise StandardError, "Second container error" if @call_count > 1
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
