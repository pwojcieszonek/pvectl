# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Services::ServiceLifecycle Tests
# =============================================================================

class ServicesServiceLifecycleTest < Minitest::Test
  def test_start_calls_start_on_repository_and_returns_pending_result
    repo = MockServiceRepo.new
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: repo)

    result = svc.execute(operation: :start, node: "pve1", service: "pveproxy")

    assert_equal [["start", "pve1", "pveproxy"]], repo.calls
    assert_instance_of Pvectl::Models::NodeOperationResult, result
    assert result.pending?
    assert_equal :start, result.operation
    assert_equal "pve1", result.node_model.name
    assert_equal "UPID:pve1:start:pveproxy", result.task_upid
  end

  def test_stop_calls_stop_on_repository
    repo = MockServiceRepo.new
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: repo)

    svc.execute(operation: :stop, node: "pve1", service: "pveproxy")

    assert_equal [["stop", "pve1", "pveproxy"]], repo.calls
  end

  def test_restart_calls_restart_on_repository
    repo = MockServiceRepo.new
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: repo)

    svc.execute(operation: :restart, node: "pve1", service: "pveproxy")

    assert_equal [["restart", "pve1", "pveproxy"]], repo.calls
  end

  def test_reload_calls_reload_on_repository
    repo = MockServiceRepo.new
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: repo)

    svc.execute(operation: :reload, node: "pve1", service: "pveproxy")

    assert_equal [["reload", "pve1", "pveproxy"]], repo.calls
  end

  def test_unknown_operation_raises
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: MockServiceRepo.new)

    assert_raises(ArgumentError) do
      svc.execute(operation: :explode, node: "pve1", service: "pveproxy")
    end
  end

  def test_api_error_returns_failed_result
    repo = MockServiceRepo.new(raise_error: "permission denied")
    svc = Pvectl::Services::ServiceLifecycle.new(service_repository: repo)

    result = svc.execute(operation: :stop, node: "pve1", service: "corosync")

    assert result.failed?
    assert_equal "permission denied", result.error
    assert_equal :stop, result.operation
  end

  class MockServiceRepo
    attr_reader :calls

    def initialize(raise_error: nil)
      @calls = []
      @raise_error = raise_error
    end

    %i[start stop restart reload].each do |op|
      define_method(op) do |node, service|
        @calls << [op.to_s, node, service]
        raise StandardError, @raise_error if @raise_error

        "UPID:#{node}:#{op}:#{service}"
      end
    end
  end
end
