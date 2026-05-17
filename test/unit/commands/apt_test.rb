# frozen_string_literal: true

require "test_helper"
require "stringio"

# =============================================================================
# Commands::Apt Tests
# =============================================================================
#
# Covers:
# - Class registration / CLI wiring (via Pvectl::CLI.commands)
# - Node resolution (--node flag, default-node config fallback, missing)
# - Repository dispatch for each subcommand
# - Argument validation (changelog requires package name)
# - Exit codes for success / failure / usage / config errors
#
class CommandsAptTest < Minitest::Test
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
    assert_kind_of Class, Pvectl::Commands::Apt
  end

  def test_cli_registers_apt_command_with_subcommands
    commands = Pvectl::CLI.commands
    assert commands.key?(:apt), "apt command should be defined"
    subcommands = commands[:apt].commands
    assert subcommands.key?(:list)
    assert subcommands.key?(:update)
    assert subcommands.key?(:changelog)
    assert subcommands.key?(:versions)
  end

  # -----------------------
  # Node resolution
  # -----------------------

  def test_list_uses_node_from_options
    repo = FakeRepo.new
    cmd = build_command(:list, [], options: { node: "pve2" }, repo: repo)

    stub_collaborators(cmd) { capture_io { cmd.execute } }

    assert_equal [["pending", "pve2"]], repo.calls
  end

  def test_list_falls_back_to_default_node
    repo = FakeRepo.new
    cmd = build_command(:list, [], repo: repo)

    stub_collaborators(cmd) { capture_io { cmd.execute } }

    assert_equal [["pending", "pve1"]], repo.calls
  end

  def test_returns_config_error_when_no_node_resolvable
    blank_config = Object.new
    def blank_config.default_node
      nil
    end

    config_service = Object.new
    cfg = blank_config
    config_service.define_singleton_method(:load) { |**_kwargs| nil }
    config_service.define_singleton_method(:current_config) { cfg }

    repo = FakeRepo.new
    cmd = build_command(:list, [], repo: repo)

    code = nil
    Pvectl::Config::Service.stub :new, config_service do
      capture_io { code = cmd.execute }
    end

    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, code
    assert_empty repo.calls
  end

  # -----------------------
  # Subcommand dispatch
  # -----------------------

  def test_list_calls_repository_pending
    repo = FakeRepo.new(pending: [Pvectl::Models::AptPackage.new(Package: "x", Version: "1", OldVersion: "0", node: "pve1")])
    cmd = build_command(:list, [], options: { node: "pve1" }, repo: repo)

    stdout, = capture_io { stub_collaborators(cmd) { cmd.execute } }

    assert_includes repo.calls.map(&:first), "pending"
    assert_match(/x/, stdout)
  end

  def test_update_calls_repository_refresh_and_prints_upid
    repo = FakeRepo.new(refresh_upid: "UPID:pve1:apt-update")
    cmd = build_command(:update, [], options: { node: "pve1", notify: false, quiet: true }, repo: repo)

    stdout, = capture_io { stub_collaborators(cmd) { cmd.execute } }

    call = repo.calls.find { |c| c.first == "refresh" }
    assert_equal ["refresh", "pve1", { notify: false, quiet: true }], call
    assert_match(/UPID:pve1:apt-update/, stdout)
  end

  def test_changelog_requires_package_name
    repo = FakeRepo.new
    cmd = build_command(:changelog, [], options: { node: "pve1" }, repo: repo)

    code = nil
    stub_collaborators(cmd) { capture_io { code = cmd.execute } }

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, code
    refute repo.calls.any? { |c| c.first == "changelog" }
  end

  def test_changelog_prints_text_and_passes_version
    repo = FakeRepo.new(changelog_text: "Changelog body...")
    output = StringIO.new
    cmd = build_command(:changelog, ["pve-manager"],
                        options: { node: "pve1", version: "8.2.4-1" }, repo: repo, output: output)

    capture_io { stub_collaborators(cmd) { cmd.execute } }

    assert_includes repo.calls, ["changelog", "pve1", "pve-manager", { version: "8.2.4-1" }]
    assert_match(/Changelog body/, output.string)
  end

  def test_changelog_prints_placeholder_when_text_empty
    repo = FakeRepo.new(changelog_text: "")
    output = StringIO.new
    cmd = build_command(:changelog, ["missing"], options: { node: "pve1" }, repo: repo, output: output)

    capture_io { stub_collaborators(cmd) { cmd.execute } }

    assert_match(/no changelog available/, output.string)
  end

  def test_versions_calls_repository_versions
    repo = FakeRepo.new(versions: [Pvectl::Models::AptPackage.new(Package: "proxmox-ve", Version: "8.2.0", CurrentState: "Installed", node: "pve1")])
    cmd = build_command(:versions, [], options: { node: "pve1" }, repo: repo)

    stdout, = capture_io { stub_collaborators(cmd) { cmd.execute } }

    assert_includes repo.calls.map(&:first), "versions"
    assert_match(/proxmox-ve/, stdout)
  end

  private

  # Test subclass that allows injection of a fake repository so we don't
  # open a real connection.
  class TestableAptCommand < Pvectl::Commands::Apt
    attr_writer :injected_repository

    private

    def repository
      @injected_repository
    end
  end

  # Fake repo that records calls and returns canned data.
  class FakeRepo
    attr_reader :calls

    def initialize(pending: [], versions: [], refresh_upid: "UPID:pve1:apt-update", changelog_text: "")
      @calls = []
      @pending = pending
      @versions = versions
      @refresh_upid = refresh_upid
      @changelog_text = changelog_text
    end

    def pending(node)
      @calls << ["pending", node]
      @pending
    end

    def refresh(node, notify: false, quiet: false)
      @calls << ["refresh", node, { notify: notify, quiet: quiet }]
      @refresh_upid
    end

    def changelog(node, package, version: nil)
      @calls << ["changelog", node, package, { version: version }]
      @changelog_text
    end

    def versions(node)
      @calls << ["versions", node]
      @versions
    end
  end

  def build_command(operation, args, options: {}, repo: nil, output: StringIO.new)
    cmd = TestableAptCommand.new(operation, args, options, {}, output: output)
    cmd.injected_repository = repo if repo
    cmd
  end

  # Stubs Pvectl::Config::Service so #load_config returns @stub_config.
  def stub_collaborators(_cmd)
    Pvectl::Config::Service.stub :new, @config_service do
      yield
    end
  end
end
