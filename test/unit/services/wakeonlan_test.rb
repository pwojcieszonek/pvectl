# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Services::Wakeonlan Tests
# =============================================================================

class ServicesWakeonlanTest < Minitest::Test
  class MockNodeRepo
    attr_reader :wakeonlan_calls

    def initialize(nodes:, mac: "AA:BB:CC:DD:EE:FF", error: nil)
      @nodes = nodes
      @mac = mac
      @error = error
      @wakeonlan_calls = []
    end

    def get(name, **_kwargs)
      @nodes.find { |n| n.name == name }
    end

    def wakeonlan(name)
      @wakeonlan_calls << name
      raise @error if @error

      @mac
    end
  end

  def setup
    @pve1 = Pvectl::Models::Node.new(name: "pve1", status: "online")
    @pve3 = Pvectl::Models::Node.new(name: "pve3", status: "offline")
  end

  def test_executes_wakeonlan_and_returns_success_result
    repo = MockNodeRepo.new(nodes: [@pve1, @pve3])
    service = Pvectl::Services::Wakeonlan.new(node_repository: repo)

    result = service.execute(node_name: "pve3")

    assert_kind_of Pvectl::Models::NodeOperationResult, result
    assert result.successful?
    assert_equal :wakeonlan, result.operation
    assert_equal "pve3", result.node_model.name
    assert_includes ["pve3"], repo.wakeonlan_calls.first
  end

  def test_result_message_contains_mac_address
    repo = MockNodeRepo.new(nodes: [@pve3], mac: "11:22:33:44:55:66")
    service = Pvectl::Services::Wakeonlan.new(node_repository: repo)

    result = service.execute(node_name: "pve3")

    assert_match(/11:22:33:44:55:66/, result.message)
  end

  def test_returns_failure_when_node_not_found
    repo = MockNodeRepo.new(nodes: [@pve1])
    service = Pvectl::Services::Wakeonlan.new(node_repository: repo)

    result = service.execute(node_name: "missing")

    assert result.failed?
    assert_match(/not found/i, result.error)
    assert_empty repo.wakeonlan_calls
  end

  def test_returns_failure_when_api_raises
    repo = MockNodeRepo.new(
      nodes: [@pve3],
      error: StandardError.new("MAC address not configured for node pve3")
    )
    service = Pvectl::Services::Wakeonlan.new(node_repository: repo)

    result = service.execute(node_name: "pve3")

    assert result.failed?
    assert_match(/MAC address not configured/, result.error)
  end
end
