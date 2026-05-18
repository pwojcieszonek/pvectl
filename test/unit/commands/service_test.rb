# frozen_string_literal: true

require "test_helper"
require "stringio"

# =============================================================================
# Commands::Service Tests
# =============================================================================
#
# Covers:
# - Class registration / CLI wiring (via Pvectl::CLI.commands)
# - Argument validation (missing service name)
# - Node resolution (--node flag, default-node config fallback)
# - Confirmation logic (--yes skips, irreversible operations require prompt)
# - Repository dispatch (service operation -> Service repo method)
# - Exit codes for success / failure / usage errors
#
class CommandsServiceTest < Minitest::Test
  def setup
    @stub_config = Object.new
    def @stub_config.default_node
      "pve1"
    end

    @config_service = Object.new
    cfg = @stub_config
    @config_service.define_singleton_method(:load) { |**_kwargs| nil }
    @config_service.define_singleton_method(:current_config) { cfg }
  end

  # -----------------------
  # Class & CLI registration
  # -----------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Commands::Service
  end

  def test_operations_constant
    assert_equal %i[start stop restart reload], Pvectl::Commands::Service::OPERATIONS
  end

  def test_confirmable_operations_includes_stop_and_restart
    assert_includes Pvectl::Commands::Service::CONFIRMABLE_OPERATIONS, :stop
    assert_includes Pvectl::Commands::Service::CONFIRMABLE_OPERATIONS, :restart
    refute_includes Pvectl::Commands::Service::CONFIRMABLE_OPERATIONS, :start
    refute_includes Pvectl::Commands::Service::CONFIRMABLE_OPERATIONS, :reload
  end

  def test_cli_registers_service_command_with_subcommands
    commands = Pvectl::CLI.commands
    assert commands.key?(:service), "service command should be defined"
    subcommands = commands[:service].commands
    assert subcommands.key?(:start)
    assert subcommands.key?(:stop)
    assert subcommands.key?(:restart)
    assert subcommands.key?(:reload)
  end

  # -----------------------
  # Argument validation
  # -----------------------

  def test_execute_returns_usage_error_when_service_name_missing
    cmd = build_command(:start, [])
    capture_io { assert_equal Pvectl::ExitCodes::USAGE_ERROR, cmd.execute }
  end

  # -----------------------
  # Node resolution
  # -----------------------

  def test_uses_node_from_options_when_provided
    cmd = build_command(:start, ["pveproxy"], options: { node: "pve2", yes: true })
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["start", "pve2", "pveproxy"]], cmd.stub_repository.calls
  end

  def test_falls_back_to_default_node_when_no_option
    cmd = build_command(:start, ["pveproxy"], options: { yes: true })
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["start", "pve1", "pveproxy"]], cmd.stub_repository.calls
  end

  def test_returns_config_error_when_no_node_resolvable
    blank_config = Object.new
    def blank_config.default_node
      nil
    end
    @stub_config = blank_config
    cfg = blank_config
    @config_service.define_singleton_method(:current_config) { cfg }

    cmd = build_command(:start, ["pveproxy"], options: { yes: true })
    cmd.stub_repository = FakeRepo.new

    code = nil
    stub_collaborators(cmd) { capture_io { code = cmd.execute } }

    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, code
    assert_empty cmd.stub_repository.calls
  end

  # -----------------------
  # Confirmation logic
  # -----------------------

  def test_irreversible_operation_skipped_with_yes_flag
    cmd = build_command(:restart, ["pveproxy"], options: { yes: true, node: "pve1" })
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["restart", "pve1", "pveproxy"]], cmd.stub_repository.calls
  end

  def test_irreversible_operation_proceeds_when_user_confirms
    stdin = StringIO.new("yes\n")
    stdout = StringIO.new
    cmd = build_command(:stop, ["pveproxy"], options: { node: "pve1" }, prompt: stdin, output: stdout)
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["stop", "pve1", "pveproxy"]], cmd.stub_repository.calls
    assert_match(/About to stop service 'pveproxy'/, stdout.string)
  end

  def test_irreversible_operation_aborted_when_user_declines
    stdin = StringIO.new("n\n")
    stdout = StringIO.new
    cmd = build_command(:stop, ["pveproxy"], options: { node: "pve1" }, prompt: stdin, output: stdout)
    cmd.stub_repository = FakeRepo.new

    code = nil
    stub_collaborators(cmd) do
      capture_io { code = cmd.execute }
    end

    assert_equal Pvectl::ExitCodes::SUCCESS, code
    assert_empty cmd.stub_repository.calls
    assert_match(/Aborted/, stdout.string)
  end

  def test_start_does_not_require_confirmation
    stdin = StringIO.new("") # no input — would block if confirmation requested
    cmd = build_command(:start, ["pveproxy"], options: { node: "pve1" }, prompt: stdin)
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["start", "pve1", "pveproxy"]], cmd.stub_repository.calls
  end

  def test_reload_does_not_require_confirmation
    stdin = StringIO.new("")
    cmd = build_command(:reload, ["pveproxy"], options: { node: "pve1" }, prompt: stdin)
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) do
      capture_io { cmd.execute }
    end

    assert_equal [["reload", "pve1", "pveproxy"]], cmd.stub_repository.calls
  end

  # -----------------------
  # Warnings
  # -----------------------

  def test_warns_about_pveproxy_during_confirmation
    stdin = StringIO.new("n\n")
    stdout = StringIO.new
    cmd = build_command(:restart, ["pveproxy"], options: { node: "pve1" }, prompt: stdin, output: stdout)
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) { capture_io { cmd.execute } }

    assert_match(/Warning.*disconnect/, stdout.string)
  end

  def test_warns_about_corosync_during_confirmation
    stdin = StringIO.new("n\n")
    stdout = StringIO.new
    cmd = build_command(:restart, ["corosync"], options: { node: "pve1" }, prompt: stdin, output: stdout)
    cmd.stub_repository = FakeRepo.new

    stub_collaborators(cmd) { capture_io { cmd.execute } }

    assert_match(/Warning.*cluster|Warning.*quorum/, stdout.string)
  end

  private

  # Test subclass that allows injection of a fake repository so we don't open
  # a real connection. Overrides #perform to plug in a stub.
  class TestableServiceCommand < Pvectl::Commands::Service
    attr_accessor :stub_repository, :last_exit_code, :execute_result

    private

    def perform(service_name, node)
      lifecycle = Pvectl::Services::ServiceLifecycle.new(service_repository: @stub_repository)
      lifecycle.execute(operation: @operation, node: node, service: service_name)
    end
  end

  # Fake repo that records calls and returns pseudo-UPIDs.
  class FakeRepo
    attr_reader :calls

    def initialize
      @calls = []
    end

    %i[start stop restart reload].each do |op|
      define_method(op) do |node, service|
        @calls << [op.to_s, node, service]
        "UPID:#{node}:#{op}:#{service}"
      end
    end
  end

  def build_command(operation, args, options: {}, prompt: StringIO.new("y\n"), output: StringIO.new)
    TestableServiceCommand.new(operation, args, options, {}, prompt: prompt, output: output)
  end

  # Stubs Pvectl::Config::Service so #load_config returns @stub_config.
  def stub_collaborators(_cmd)
    Pvectl::Config::Service.stub :new, @config_service do
      yield
    end
  end
end
