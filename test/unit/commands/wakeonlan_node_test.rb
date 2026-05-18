# frozen_string_literal: true

require "test_helper"
require "stringio"

# =============================================================================
# Commands::WakeonlanNode Tests
# =============================================================================

class CommandsWakeonlanNodeTest < Minitest::Test
  class FakeService
    attr_reader :received_node_name, :result

    def initialize(result)
      @result = result
    end

    def execute(node_name:)
      @received_node_name = node_name
      @result
    end
  end

  def setup
    @node = Pvectl::Models::Node.new(name: "pve3", status: "offline")
  end

  def successful_result(message: "Wake-on-LAN packet sent (MAC: AA:BB:CC:DD:EE:FF)")
    Pvectl::Models::NodeOperationResult.new(
      operation: :wakeonlan,
      node_model: @node,
      resource: { node_name: "pve3" },
      success: true,
      message: message
    )
  end

  def failure_result(error: "Node pve3 not found")
    Pvectl::Models::NodeOperationResult.new(
      operation: :wakeonlan,
      node_model: @node,
      resource: { node_name: "pve3" },
      success: false,
      error: error
    )
  end

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  def test_command_class_exists
    assert_kind_of Class, Pvectl::Commands::WakeonlanNode
  end

  def test_calls_service_with_node_name
    service = FakeService.new(successful_result)
    cmd = Pvectl::Commands::WakeonlanNode.new(
      "pve3", {}, { output: "table" }, service: service
    )

    capture_stdout { cmd.execute }

    assert_equal "pve3", service.received_node_name
  end

  def test_returns_success_exit_code_on_success
    cmd = Pvectl::Commands::WakeonlanNode.new(
      "pve3", {}, { output: "table" }, service: FakeService.new(successful_result)
    )

    exit_code = nil
    capture_stdout { exit_code = cmd.execute }

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_outputs_table_with_mac_address_on_success
    cmd = Pvectl::Commands::WakeonlanNode.new(
      "pve3", {}, { output: "table" }, service: FakeService.new(successful_result)
    )

    output = capture_stdout { cmd.execute }

    assert_match(/pve3/, output)
    assert_match(/AA:BB:CC:DD:EE:FF/, output)
  end

  def test_returns_general_error_on_failure
    cmd = Pvectl::Commands::WakeonlanNode.new(
      "pve3", {}, { output: "table" },
      service: FakeService.new(failure_result(error: "MAC address not configured"))
    )

    exit_code = nil
    capture_stdout { exit_code = cmd.execute }

    refute_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_missing_node_argument_returns_usage_error
    cmd = Pvectl::Commands::WakeonlanNode.new(
      nil, {}, { output: "table" }, service: FakeService.new(successful_result)
    )

    exit_code = nil
    err = capture_stderr { exit_code = cmd.execute }

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
    assert_match(/NODE/i, err)
  end

  private

  def capture_stderr
    old = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old
  end
end
