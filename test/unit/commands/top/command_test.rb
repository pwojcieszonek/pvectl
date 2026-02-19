# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Top::Command Tests - Basic Structure
# =============================================================================

class TopCommandBasicTest < Minitest::Test
  def test_command_class_exists
    assert_kind_of Class, Pvectl::Commands::Top::Command
  end

  def test_execute_class_method_exists
    assert_respond_to Pvectl::Commands::Top::Command, :execute
  end
end

# =============================================================================
# Commands::Top::Command Tests - Missing Resource Type
# =============================================================================

class TopCommandMissingResourceTypeTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_resource_type_is_nil
    exit_code = Pvectl::Commands::Top::Command.execute(nil, {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_message_when_resource_type_is_nil
    Pvectl::Commands::Top::Command.execute(nil, {}, {})
    stderr_output = $stderr.string
    assert_includes stderr_output, "Error: resource type is required"
  end

  def test_outputs_usage_hint_when_resource_type_is_nil
    Pvectl::Commands::Top::Command.execute(nil, {}, {})
    stderr_output = $stderr.string
    assert_includes stderr_output, "Usage: pvectl top RESOURCE_TYPE"
  end
end

# =============================================================================
# Commands::Top::Command Tests - Unknown Resource Type
# =============================================================================

class TopCommandUnknownResourceTypeTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_for_unknown_resource
    exit_code = Pvectl::Commands::Top::Command.execute("unknown", {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_for_unknown_resource
    Pvectl::Commands::Top::Command.execute("unknown", {}, {})
    stderr_output = $stderr.string
    assert_includes stderr_output, "Unknown resource type: unknown"
  end

  def test_accepts_nodes_resource_type
    exit_code = Pvectl::Commands::Top::Command.execute("nodes", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_node_alias
    exit_code = Pvectl::Commands::Top::Command.execute("node", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end
end

# =============================================================================
# Commands::Top::Command Tests - VM Resource Type
# =============================================================================

class TopCommandVmResourceTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_accepts_vms_resource_type
    exit_code = Pvectl::Commands::Top::Command.execute("vms", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_vm_alias
    exit_code = Pvectl::Commands::Top::Command.execute("vm", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_containers_resource_type
    exit_code = Pvectl::Commands::Top::Command.execute("containers", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_container_alias
    exit_code = Pvectl::Commands::Top::Command.execute("container", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_ct_alias
    exit_code = Pvectl::Commands::Top::Command.execute("ct", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_accepts_cts_alias
    exit_code = Pvectl::Commands::Top::Command.execute("cts", {}, {})
    refute_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end
end

# =============================================================================
# Commands::Top::Command Tests - VM Delegation
# =============================================================================

class TopCommandVmDelegationTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    @running_vm = Pvectl::Models::Vm.new(
      vmid: 100, name: "web", status: "running", node: "pve1",
      cpu: 0.5, maxcpu: 4, mem: 2_147_483_648, maxmem: 4_294_967_296,
      disk: 10_737_418_240, maxdisk: 53_687_091_200, uptime: 86_400
    )

    @stopped_vm = Pvectl::Models::Vm.new(
      vmid: 200, name: "dev", status: "stopped", node: "pve2",
      cpu: nil, maxcpu: 2, mem: nil, maxmem: 2_147_483_648
    )
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_uses_top_vm_presenter
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [@running_vm], [], sort: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TopVm.new

    command = Pvectl::Commands::Top::Command.new("vms", {}, {}, handler: mock_handler)
    command.execute

    stdout_output = $stdout.string
    assert_includes stdout_output, "100"
    mock_handler.verify
  end

  def test_filters_running_only_by_default
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [@running_vm, @stopped_vm], [], sort: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TopVm.new

    command = Pvectl::Commands::Top::Command.new("vms", {}, {}, handler: mock_handler)
    command.execute

    stdout_output = $stdout.string
    assert_includes stdout_output, "100"
    refute_includes stdout_output, "200"
    mock_handler.verify
  end

  def test_shows_all_with_all_flag
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [@running_vm, @stopped_vm], [], sort: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TopVm.new

    command = Pvectl::Commands::Top::Command.new("vms", { all: true }, {}, handler: mock_handler)
    command.execute

    stdout_output = $stdout.string
    assert_includes stdout_output, "100"
    assert_includes stdout_output, "200"
    mock_handler.verify
  end

  def test_nodes_shows_all_regardless_of_all_flag
    node = Pvectl::Models::Node.new(
      name: "pve1", status: "online", cpu: 0.23, maxcpu: 16,
      mem: 48_535_150_182, maxmem: 137_438_953_472,
      disk: 1_288_490_188_800, maxdisk: 4_398_046_511_104,
      uptime: 3_898_800, guests_vms: 5, guests_cts: 3,
      loadavg: [0.45, 0.52, 0.48], swap_used: 0, swap_total: 8_589_934_592
    )

    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [node], [], sort: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TopNode.new

    command = Pvectl::Commands::Top::Command.new("nodes", {}, {}, handler: mock_handler)
    command.execute

    stdout_output = $stdout.string
    assert_includes stdout_output, "pve1"
    mock_handler.verify
  end
end

# =============================================================================
# Commands::Top::Command Tests - Delegation
# =============================================================================

class TopCommandDelegationTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    @node = Pvectl::Models::Node.new(
      name: "pve1", status: "online", cpu: 0.23, maxcpu: 16,
      mem: 48_535_150_182, maxmem: 137_438_953_472,
      disk: 1_288_490_188_800, maxdisk: 4_398_046_511_104,
      uptime: 3_898_800, guests_vms: 5, guests_cts: 3,
      loadavg: [0.45, 0.52, 0.48], swap_used: 0, swap_total: 8_589_934_592
    )
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_uses_top_node_presenter
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [@node], [], sort: nil
    mock_handler.expect :presenter, Pvectl::Presenters::TopNode.new

    command = Pvectl::Commands::Top::Command.new("nodes", {}, {}, handler: mock_handler)
    command.execute

    stdout_output = $stdout.string
    # TopNode presenter outputs CPU(cores) column -- verify cores value is in output
    assert_includes stdout_output, "16"
    mock_handler.verify
  end

  def test_passes_sort_option_to_handler
    mock_handler = Minitest::Mock.new
    mock_handler.expect :list, [@node], [], sort: "cpu"
    mock_handler.expect :presenter, Pvectl::Presenters::TopNode.new

    command = Pvectl::Commands::Top::Command.new(
      "nodes", { :"sort-by" => "cpu" }, {}, handler: mock_handler
    )
    command.execute

    mock_handler.verify
  end
end
