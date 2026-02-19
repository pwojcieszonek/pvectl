# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config SetContext Command Tests
# =============================================================================

class ConfigSetContextCommandTest < Minitest::Test
  # Tests for `pvectl config set-context <name> [options]` command

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  # ---------------------------
  # Command Registration Tests
  # ---------------------------

  def test_config_command_exists
    commands = Pvectl::CLI.commands
    assert commands.key?(:config), "config command should be defined"
  end

  def test_config_has_set_context_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:"set-context"), "set-context subcommand should be defined"
  end

  def test_set_context_has_cluster_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_context_cmd = config_cmd.commands[:"set-context"]
    assert set_context_cmd, "set-context command not found"

    flags = set_context_cmd.flags
    assert flags.key?(:cluster), "set-context should have --cluster flag"
  end

  def test_set_context_has_user_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_context_cmd = config_cmd.commands[:"set-context"]
    assert set_context_cmd, "set-context command not found"

    flags = set_context_cmd.flags
    assert flags.key?(:user), "set-context should have --user flag"
  end

  def test_set_context_has_default_node_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_context_cmd = config_cmd.commands[:"set-context"]
    assert set_context_cmd, "set-context command not found"

    flags = set_context_cmd.flags
    # Check for default-node or default_node
    has_default_node = flags.key?(:"default-node") || flags.key?(:default_node)
    assert has_default_node, "set-context should have --default-node flag"
  end

  # ---------------------------
  # Command Execution Tests
  # ---------------------------

  def test_set_context_creates_new_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=production",
      "--user=admin-prod",
      "staging"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the context was created in file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["contexts"].find { |c| c["name"] == "staging" }
    assert staging, "staging context should be created"
    assert_equal "production", staging["context"]["cluster"]
    assert_equal "admin-prod", staging["context"]["user"]
  end

  def test_set_context_updates_existing_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=development",
      "--user=admin-dev",
      "prod"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the context was updated
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    prod = loaded["contexts"].find { |c| c["name"] == "prod" }
    assert_equal "development", prod["context"]["cluster"]
    assert_equal "admin-dev", prod["context"]["user"]
  end

  def test_set_context_with_default_node
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=production",
      "--user=admin-prod",
      "--default-node=pve1",
      "staging"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["contexts"].find { |c| c["name"] == "staging" }
    assert_equal "pve1", staging["context"]["default-node"]
  end

  def test_set_context_outputs_confirmation
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=production",
      "--user=admin-prod",
      "staging"
    )

    assert_match(/context.*staging|created|modified/i, result[:stdout])
  end

  def test_set_context_fails_without_name
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "set-context")

    # GLI should return error for missing required argument
    refute_equal 0, result[:exit_code]
  end

  def test_set_context_fails_for_unknown_cluster
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=nonexistent",
      "--user=admin-prod",
      "staging"
    )

    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, result[:exit_code]
    assert_match(/cluster.*not found|unknown cluster/i, result[:stderr])
  end

  def test_set_context_fails_for_unknown_user
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: GLI requires flags before positional arguments
    result = run_cli_command(
      "config", "set-context",
      "--cluster=production",
      "--user=nonexistent",
      "staging"
    )

    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, result[:exit_code]
    assert_match(/user.*not found|unknown user/i, result[:stderr])
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end

  def run_cli_command(*args)
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new

    exit_code = nil
    begin
      exit_code = Pvectl::CLI.run(args)
    rescue SystemExit => e
      exit_code = e.status
    end

    stdout_output = $stdout.string
    stderr_output = $stderr.string

    $stdout = old_stdout
    $stderr = old_stderr

    { exit_code: exit_code || 0, stdout: stdout_output, stderr: stderr_output }
  end
end
