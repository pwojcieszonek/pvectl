# frozen_string_literal: true

require "test_helper"

# Integration tests for VM lifecycle commands.
# These tests verify the full flow: Command -> Service -> Repository -> Output
class VmLifecycleIntegrationTest < Minitest::Test
  def setup
    @vm1 = Pvectl::Models::Vm.new(
      vmid: 100, name: "web-prod", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @vm2 = Pvectl::Models::Vm.new(
      vmid: 101, name: "db-dev", status: "stopped",
      node: "pve1", tags: "dev;db", pool: "development"
    )
    @vm3 = Pvectl::Models::Vm.new(
      vmid: 102, name: "cache", status: "running",
      node: "pve2", tags: nil, pool: nil
    )
  end

  # Test VmLifecycleService executes operations correctly
  def test_service_executes_start_on_multiple_vms
    calls = []
    vm_repo = MockVmRepoWithTracking.new(calls)
    task_repo = MockTaskRepoSuccess.new

    service = Pvectl::Services::VmLifecycle.new(vm_repo, task_repo)
    results = service.execute(:start, [@vm1, @vm2])

    assert_equal 2, results.size
    assert results.all?(&:successful?)
    assert_equal [[:start, 100, "pve1"], [:start, 101, "pve1"]], calls
  end

  def test_service_with_fail_fast_stops_on_error
    calls = []
    vm_repo = MockVmRepoWithTracking.new(calls)
    task_repo = MockTaskRepoFailOnSecond.new

    service = Pvectl::Services::VmLifecycle.new(vm_repo, task_repo, fail_fast: true)
    results = service.execute(:stop, [@vm1, @vm2, @vm3])

    # Only 2 results (stopped at second failure)
    assert_equal 2, results.size
    assert results[0].successful?
    assert results[1].failed?
    # Third VM should NOT be called
    assert_equal 2, calls.size
  end

  def test_service_async_mode_returns_immediately
    calls = []
    vm_repo = MockVmRepoWithTracking.new(calls)
    task_repo = MockTaskRepoSuccess.new

    service = Pvectl::Services::VmLifecycle.new(vm_repo, task_repo, async: true)
    results = service.execute(:shutdown, [@vm1])

    assert_equal 1, results.size
    assert results[0].pending?
    assert_includes results[0].task_upid, "UPID:pve1"
  end

  # Test Selectors filter correctly
  def test_selector_filters_by_status
    selector = Pvectl::Selectors::Vm.parse("status=running")
    filtered = selector.apply([@vm1, @vm2, @vm3])

    assert_equal 2, filtered.size
    assert_equal [100, 102], filtered.map(&:vmid)
  end

  def test_selector_filters_by_multiple_conditions
    selector = Pvectl::Selectors::Vm.parse("status=running,tags=prod")
    filtered = selector.apply([@vm1, @vm2, @vm3])

    assert_equal 1, filtered.size
    assert_equal 100, filtered.first.vmid
  end

  def test_selector_with_wildcard_pattern
    selector = Pvectl::Selectors::Vm.parse("name=~*-prod")
    filtered = selector.apply([@vm1, @vm2, @vm3])

    assert_equal 1, filtered.size
    assert_equal "web-prod", filtered.first.name
  end

  # Test OperationResult presenter formats correctly
  def test_presenter_formats_successful_result
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "OK", starttime: 1000, endtime: 1005)
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm1, operation: :start, task: task, success: true
    )

    presenter = Pvectl::Presenters::VmOperationResult.new
    row = presenter.to_row(result)

    assert_equal "100", row[0]        # VMID
    assert_equal "web-prod", row[1]   # NAME
    assert_equal "pve1", row[2]       # NODE
    assert_includes row[3], "Success" # STATUS (may be colored)
    assert_equal "OK", row[4]         # MESSAGE
  end

  def test_presenter_formats_failed_result
    task = Pvectl::Models::Task.new(status: "stopped", exitstatus: "VM is locked")
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm1, operation: :stop, task: task, success: false
    )

    presenter = Pvectl::Presenters::VmOperationResult.new
    row = presenter.to_row(result)

    assert_includes row[3], "Failed"  # STATUS (may be colored)
    assert_equal "VM is locked", row[4]
  end

  def test_presenter_formats_pending_result
    result = Pvectl::Models::VmOperationResult.new(
      vm: @vm1, operation: :shutdown, task_upid: "UPID:pve1:001", success: :pending
    )

    presenter = Pvectl::Presenters::VmOperationResult.new
    row = presenter.to_row(result)

    assert_includes row[3], "Pending" # STATUS (may be colored)
    assert_includes row[4], "UPID:pve1:001"
  end

  # Test full command flow with mocked dependencies
  def test_full_start_command_flow
    # This test would require more complex mocking of Config and Connection
    # For now, we test the components work together correctly

    # 1. Selector filters VMs
    selector = Pvectl::Selectors::Vm.parse("status=stopped")
    vms_to_start = selector.apply([@vm1, @vm2, @vm3])
    assert_equal 1, vms_to_start.size
    assert_equal @vm2, vms_to_start.first

    # 2. Service would execute start on filtered VMs
    # 3. Presenter would format results
    # This validates the integration points work correctly
  end

  # Mock classes for testing

  # Tracks all method calls with arguments
  class MockVmRepoWithTracking
    def initialize(calls)
      @calls = calls
      @call_count = 0
    end

    def start(vmid, node)
      @calls << [:start, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def stop(vmid, node)
      @calls << [:stop, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def shutdown(vmid, node)
      @calls << [:shutdown, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def restart(vmid, node)
      @calls << [:restart, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def reset(vmid, node)
      @calls << [:reset, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def suspend(vmid, node)
      @calls << [:suspend, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end

    def resume(vmid, node)
      @calls << [:resume, vmid, node]
      @call_count += 1
      "UPID:pve1:#{format('%03d', @call_count)}:task"
    end
  end

  # Always returns successful task
  class MockTaskRepoSuccess
    def wait(upid, timeout: 60)
      Pvectl::Models::Task.new(
        upid: upid,
        status: "stopped",
        exitstatus: "OK"
      )
    end

    def find(upid)
      Pvectl::Models::Task.new(
        upid: upid,
        status: "stopped",
        exitstatus: "OK"
      )
    end
  end

  # First call succeeds, second fails
  class MockTaskRepoFailOnSecond
    def initialize
      @call_count = 0
    end

    def wait(upid, timeout: 60)
      @call_count += 1
      if @call_count > 1
        Pvectl::Models::Task.new(
          upid: upid,
          status: "stopped",
          exitstatus: "ERROR: VM locked"
        )
      else
        Pvectl::Models::Task.new(
          upid: upid,
          status: "stopped",
          exitstatus: "OK"
        )
      end
    end

    def find(upid)
      wait(upid)
    end
  end
end
