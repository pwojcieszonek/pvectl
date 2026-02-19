# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config UseContext Command Tests
# =============================================================================

class ConfigUseContextCommandTest < Minitest::Test
  # Tests for `pvectl config use-context <name>` command

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

  def test_config_has_use_context_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:"use-context"), "use-context subcommand should be defined"
  end

  def test_use_context_requires_context_name_argument
    config_cmd = Pvectl::CLI.commands[:config]
    use_context_cmd = config_cmd.commands[:"use-context"]
    assert use_context_cmd, "use-context command not found"

    # Verify the command handles missing args by checking runtime behavior
    # The action block checks for empty args and returns an error
    # We can't easily test the arg_name configuration, but we test the behavior
    # in test_use_context_fails_without_argument
  end

  # ---------------------------
  # Command Execution Tests
  # ---------------------------

  def test_use_context_switches_active_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Run the command
    result = run_cli_command("config", "use-context", "dev")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the context was switched in file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal "dev", loaded["current-context"]
  end

  def test_use_context_outputs_confirmation_message
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "use-context", "dev")

    assert_match(/switched.*dev|context.*dev/i, result[:stdout])
  end

  def test_use_context_fails_for_unknown_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "use-context", "nonexistent")

    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, result[:exit_code]
    assert_match(/not found|unknown context/i, result[:stderr])
  end

  def test_use_context_fails_without_argument
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "use-context")

    # GLI should return usage error for missing required argument
    refute_equal 0, result[:exit_code]
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end

  def run_cli_command(*args)
    # Capture stdout and stderr
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
