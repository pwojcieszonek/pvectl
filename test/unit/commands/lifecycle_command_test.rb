# frozen_string_literal: true

require "test_helper"
require "stringio"

class CommandsResourceLifecycleCommandTest < Minitest::Test
  def test_module_exists
    assert_kind_of Module, Pvectl::Commands::ResourceLifecycleCommand
  end

  def test_class_methods_module_exists
    assert_kind_of Module, Pvectl::Commands::ResourceLifecycleCommand::ClassMethods
  end
end

class CommandsVmLifecycleCommandTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
  end

  def test_module_exists
    assert_kind_of Module, Pvectl::Commands::VmLifecycleCommand
  end

  def test_including_class_gets_execute_class_method
    assert Pvectl::Commands::Start.respond_to?(:execute)
    assert Pvectl::Commands::Stop.respond_to?(:execute)
    assert Pvectl::Commands::Shutdown.respond_to?(:execute)
    assert Pvectl::Commands::Restart.respond_to?(:execute)
    assert Pvectl::Commands::Reset.respond_to?(:execute)
    assert Pvectl::Commands::Suspend.respond_to?(:execute)
    assert Pvectl::Commands::Resume.respond_to?(:execute)
  end

  # Multi-VMID support tests

  def test_execute_with_empty_vmids_and_no_all_flag_returns_usage_error
    result = Pvectl::Commands::Start.execute("vm", [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
  end

  def test_execute_with_all_flag_does_not_require_vmids
    cmd = Pvectl::Commands::Start.new("vm", [], { all: true }, {})
    assert_equal [], cmd.instance_variable_get(:@resource_ids)
    assert cmd.instance_variable_get(:@options)[:all]
  end

  def test_initializes_with_array_of_resource_ids
    cmd = Pvectl::Commands::Start.new("vm", %w[100 101 102], {}, {})
    assert_equal %w[100 101 102], cmd.instance_variable_get(:@resource_ids)
  end

  def test_initializes_with_single_resource_id_converted_to_array
    cmd = Pvectl::Commands::Start.new("vm", "100", {}, {})
    assert_equal ["100"], cmd.instance_variable_get(:@resource_ids)
  end

  def test_initializes_with_nil_resource_id_as_empty_array
    cmd = Pvectl::Commands::Start.new("vm", nil, {}, {})
    assert_equal [], cmd.instance_variable_get(:@resource_ids)
  end
end

class VmLifecycleCommandConfirmationTest < Minitest::Test
  class TestableCommand
    include Pvectl::Commands::VmLifecycleCommand
    OPERATION = :start

    def test_confirm_operation(resources)
      confirm_operation(resources)
    end
  end

  def setup
    @vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "web-server-1", node: "pve1")
    @vm2 = Pvectl::Models::Vm.new(vmid: 101, name: "web-server-2", node: "pve1")
    @vm3 = Pvectl::Models::Vm.new(vmid: 102, name: "db-server", node: "pve2")
  end

  def test_skips_confirmation_for_single_vm
    cmd = TestableCommand.new("vm", ["100"], {}, {})
    result = cmd.test_confirm_operation([@vm1])
    assert result, "Single VM should not require confirmation"
  end

  def test_skips_confirmation_with_yes_flag
    cmd = TestableCommand.new("vm", %w[100 101], { yes: true }, {})
    result = cmd.test_confirm_operation([@vm1, @vm2])
    assert result, "--yes flag should skip confirmation"
  end

  def test_confirms_multi_vm_operation_with_y_response
    cmd = TestableCommand.new("vm", %w[100 101], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("y\n")
    $stdout = StringIO.new

    begin
      result = cmd.test_confirm_operation([@vm1, @vm2])
      assert result, "Should proceed with 'y' response"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  def test_confirms_multi_vm_operation_with_yes_response
    cmd = TestableCommand.new("vm", %w[100 101], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("yes\n")
    $stdout = StringIO.new

    begin
      result = cmd.test_confirm_operation([@vm1, @vm2])
      assert result, "Should proceed with 'yes' response"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  def test_aborts_multi_vm_operation_with_n_response
    cmd = TestableCommand.new("vm", %w[100 101], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    begin
      result = cmd.test_confirm_operation([@vm1, @vm2])
      refute result, "Should abort with 'n' response"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  def test_aborts_multi_vm_operation_with_empty_response
    cmd = TestableCommand.new("vm", %w[100 101], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("\n")
    $stdout = StringIO.new

    begin
      result = cmd.test_confirm_operation([@vm1, @vm2])
      refute result, "Should abort with empty response (default No)"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  def test_confirmation_prompt_format
    cmd = TestableCommand.new("vm", %w[100 101 102], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    begin
      cmd.test_confirm_operation([@vm1, @vm2, @vm3])
      output_str = output.string

      assert_includes output_str, "You are about to start 3 VMs:"
      assert_includes output_str, "100 (web-server-1) on pve1"
      assert_includes output_str, "101 (web-server-2) on pve1"
      assert_includes output_str, "102 (db-server) on pve2"
      assert_includes output_str, "Proceed? [y/N]:"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  def test_confirmation_handles_unnamed_vm
    unnamed_vm = Pvectl::Models::Vm.new(vmid: 200, name: nil, node: "pve1")
    cmd = TestableCommand.new("vm", %w[100 200], {}, {})

    original_stdin = $stdin
    original_stdout = $stdout
    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    begin
      cmd.test_confirm_operation([@vm1, unnamed_vm])
      output_str = output.string

      assert_includes output_str, "200 (unnamed) on pve1"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end
end

class VmLifecycleCommandResolveResourcesTest < Minitest::Test
  class TestableCommand
    include Pvectl::Commands::VmLifecycleCommand
    OPERATION = :start

    def test_resolve_resources(repo)
      resolve_resources(repo)
    end
  end

  def setup
    @vm1 = Pvectl::Models::Vm.new(vmid: 100, name: "web-1", node: "pve1")
    @vm2 = Pvectl::Models::Vm.new(vmid: 101, name: "web-2", node: "pve1")
    @vm3 = Pvectl::Models::Vm.new(vmid: 102, name: "db-1", node: "pve2")
  end

  def test_resolve_resources_with_vmids
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:get, @vm1, [100])
    mock_repo.expect(:get, @vm2, [101])

    cmd = TestableCommand.new("vm", %w[100 101], {}, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 2, vms.size
    assert_equal [@vm1, @vm2], vms
    mock_repo.verify
  end

  def test_resolve_resources_with_all_flag
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:list, [@vm1, @vm2, @vm3]) do |node:|
      node.nil?
    end

    cmd = TestableCommand.new("vm", [], { all: true }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 3, vms.size
    mock_repo.verify
  end

  def test_resolve_resources_with_all_and_node_filter
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:list, [@vm1, @vm2]) do |node:|
      node == "pve1"
    end

    cmd = TestableCommand.new("vm", [], { all: true, node: "pve1" }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 2, vms.size
    mock_repo.verify
  end

  def test_resolve_resources_with_vmids_and_node_filter
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:get, @vm1, [100])
    mock_repo.expect(:get, @vm3, [102])

    cmd = TestableCommand.new("vm", %w[100 102], { node: "pve1" }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 1, vms.size
    assert_equal @vm1, vms.first
    mock_repo.verify
  end

  def test_resolve_resources_filters_nil_results
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:get, @vm1, [100])
    mock_repo.expect(:get, nil, [999])

    cmd = TestableCommand.new("vm", %w[100 999], {}, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 1, vms.size
    assert_equal @vm1, vms.first
    mock_repo.verify
  end
end

class VmLifecycleCommandSelectorIntegrationTest < Minitest::Test
  class TestableCommand
    include Pvectl::Commands::VmLifecycleCommand
    OPERATION = :stop

    def test_resolve_resources(repo)
      resolve_resources(repo)
    end

    def test_selector_strings
      selector_strings
    end

    def test_apply_selectors(resources)
      apply_selectors(resources)
    end
  end

  def setup
    @running_vm1 = Pvectl::Models::Vm.new(
      vmid: 100, name: "web-prod-1", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @running_vm2 = Pvectl::Models::Vm.new(
      vmid: 101, name: "web-prod-2", status: "running",
      node: "pve1", tags: "prod;web", pool: "production"
    )
    @stopped_vm = Pvectl::Models::Vm.new(
      vmid: 102, name: "db-dev", status: "stopped",
      node: "pve2", tags: "dev;database", pool: "development"
    )
    @all_vms = [@running_vm1, @running_vm2, @stopped_vm]
  end

  def test_execute_with_selector_does_not_require_vmids
    cmd = TestableCommand.new("vm", [], { selector: ["status=running"] }, {})
    assert cmd.instance_variable_get(:@options)[:selector]
    assert_equal [], cmd.instance_variable_get(:@resource_ids)
  end

  def test_execute_validation_error_without_vmids_all_or_selector
    original_stderr = $stderr
    $stderr = StringIO.new

    begin
      result = Pvectl::Commands::Stop.execute("vm", [], {}, {})
      assert_equal Pvectl::ExitCodes::USAGE_ERROR, result
      assert_includes $stderr.string, "VMID, --all, or -l selector required"
    ensure
      $stderr = original_stderr
    end
  end

  def test_selector_strings_returns_selector_option
    cmd = TestableCommand.new("vm", [], { selector: ["status=running"] }, {})
    assert_equal ["status=running"], cmd.test_selector_strings
  end

  def test_selector_strings_returns_l_option
    cmd = TestableCommand.new("vm", [], { l: ["tags=prod"] }, {})
    assert_equal ["tags=prod"], cmd.test_selector_strings
  end

  def test_selector_strings_returns_multiple_selectors
    cmd = TestableCommand.new("vm", [], { selector: ["status=running", "tags=prod"] }, {})
    assert_equal ["status=running", "tags=prod"], cmd.test_selector_strings
  end

  def test_selector_strings_returns_empty_array_when_no_selector
    cmd = TestableCommand.new("vm", [], {}, {})
    assert_equal [], cmd.test_selector_strings
  end

  def test_apply_selectors_filters_by_status
    cmd = TestableCommand.new("vm", [], { selector: ["status=running"] }, {})
    result = cmd.test_apply_selectors(@all_vms)

    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_apply_selectors_filters_by_tags
    cmd = TestableCommand.new("vm", [], { selector: ["tags=prod"] }, {})
    result = cmd.test_apply_selectors(@all_vms)

    assert_equal 2, result.size
    assert_equal [100, 101], result.map(&:vmid)
  end

  def test_apply_selectors_multiple_conditions
    cmd = TestableCommand.new("vm", [], { selector: ["status=running,tags=prod"] }, {})
    result = cmd.test_apply_selectors(@all_vms)

    assert_equal 2, result.size
  end

  def test_apply_selectors_multiple_selector_flags
    cmd = TestableCommand.new("vm", [], { selector: ["status=stopped", "tags=dev"] }, {})
    result = cmd.test_apply_selectors(@all_vms)

    assert_equal 1, result.size
    assert_equal 102, result.first.vmid
  end

  def test_apply_selectors_returns_all_when_empty
    cmd = TestableCommand.new("vm", [], {}, {})
    result = cmd.test_apply_selectors(@all_vms)

    assert_equal 3, result.size
  end

  def test_resolve_resources_with_selector_only
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:list, @all_vms) { |node:| node.nil? }

    cmd = TestableCommand.new("vm", [], { selector: ["status=running"] }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 2, vms.size
    assert_equal [100, 101], vms.map(&:vmid)
    mock_repo.verify
  end

  def test_resolve_resources_with_selector_and_node
    pve1_vms = [@running_vm1, @running_vm2]
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:list, pve1_vms) { |node:| node == "pve1" }

    cmd = TestableCommand.new("vm", [], { selector: ["status=running"], node: "pve1" }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 2, vms.size
    mock_repo.verify
  end

  def test_resolve_resources_with_all_and_selector
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:list, @all_vms) { |node:| node.nil? }

    cmd = TestableCommand.new("vm", [], { all: true, selector: ["status=stopped"] }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 1, vms.size
    assert_equal 102, vms.first.vmid
    mock_repo.verify
  end

  def test_resolve_resources_with_vmids_and_selector
    mock_repo = Minitest::Mock.new
    mock_repo.expect(:get, @running_vm1, [100])
    mock_repo.expect(:get, @stopped_vm, [102])

    cmd = TestableCommand.new("vm", %w[100 102], { selector: ["status=running"] }, {})
    vms = cmd.test_resolve_resources(mock_repo)

    assert_equal 1, vms.size
    assert_equal 100, vms.first.vmid
    mock_repo.verify
  end

  def test_resolve_resources_returns_empty_without_selector_vmids_or_all
    cmd = TestableCommand.new("vm", [], {}, {})
    mock_repo = Minitest::Mock.new

    vms = cmd.test_resolve_resources(mock_repo)

    assert_empty vms
    mock_repo.verify
  end
end

class VmLifecycleCommandServiceOptionsTest < Minitest::Test
  class TestableCommand
    include Pvectl::Commands::VmLifecycleCommand
    OPERATION = :start

    def test_service_options
      service_options
    end
  end

  def test_service_options_includes_timeout
    cmd = TestableCommand.new("vm", ["100"], { timeout: 120 }, {})
    opts = cmd.test_service_options
    assert_equal 120, opts[:timeout]
  end

  def test_service_options_excludes_timeout_when_not_set
    cmd = TestableCommand.new("vm", ["100"], {}, {})
    opts = cmd.test_service_options
    assert_nil opts[:timeout]
  end

  def test_service_options_includes_async
    cmd = TestableCommand.new("vm", ["100"], { async: true }, {})
    opts = cmd.test_service_options
    assert_equal true, opts[:async]
  end

  def test_service_options_excludes_async_when_not_set
    cmd = TestableCommand.new("vm", ["100"], {}, {})
    opts = cmd.test_service_options
    assert_nil opts[:async]
  end

  def test_service_options_includes_wait
    cmd = TestableCommand.new("vm", ["100"], { wait: true }, {})
    opts = cmd.test_service_options
    assert_equal true, opts[:wait]
  end

  def test_service_options_excludes_wait_when_not_set
    cmd = TestableCommand.new("vm", ["100"], {}, {})
    opts = cmd.test_service_options
    assert_nil opts[:wait]
  end

  def test_service_options_includes_fail_fast
    cmd = TestableCommand.new("vm", ["100"], { "fail-fast": true }, {})
    opts = cmd.test_service_options
    assert_equal true, opts[:fail_fast]
  end

  def test_service_options_excludes_fail_fast_when_not_set
    cmd = TestableCommand.new("vm", ["100"], {}, {})
    opts = cmd.test_service_options
    assert_nil opts[:fail_fast]
  end

  def test_service_options_includes_multiple_options
    cmd = TestableCommand.new("vm", ["100"], { timeout: 60, async: true, "fail-fast": true }, {})
    opts = cmd.test_service_options
    assert_equal 60, opts[:timeout]
    assert_equal true, opts[:async]
    assert_equal true, opts[:fail_fast]
  end
end
