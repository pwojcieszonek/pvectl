# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config GetContexts Command Tests
# =============================================================================

class ConfigGetContextsCommandTest < Minitest::Test
  # Tests for `pvectl config get-contexts` command

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

  def test_config_has_get_contexts_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:"get-contexts"), "get-contexts subcommand should be defined"
  end

  # ---------------------------
  # Command Execution Tests
  # ---------------------------

  def test_get_contexts_lists_all_contexts
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "get-contexts")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"
    assert_match(/prod/, result[:stdout])
    assert_match(/dev/, result[:stdout])
  end

  def test_get_contexts_shows_current_context_indicator
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "get-contexts")

    # The current context should be marked with *
    lines = result[:stdout].lines
    current_line = lines.find { |l| l.include?("prod") }
    assert current_line, "prod context line not found"
    assert_match(/\*/, current_line, "Current context should be marked with *")
  end

  def test_get_contexts_shows_table_header
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "get-contexts")

    assert_match(/CURRENT/i, result[:stdout])
    assert_match(/NAME/i, result[:stdout])
    assert_match(/CLUSTER/i, result[:stdout])
    assert_match(/USER/i, result[:stdout])
  end

  def test_get_contexts_shows_cluster_references
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "get-contexts")

    assert_match(/production/, result[:stdout])
    assert_match(/development/, result[:stdout])
  end

  def test_get_contexts_shows_user_references
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "get-contexts")

    assert_match(/admin-prod/, result[:stdout])
    assert_match(/admin-dev/, result[:stdout])
  end

  # ---------------------------
  # Output Format Tests
  # ---------------------------

  def test_get_contexts_json_output
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: Global flags like -o must come before the command in GLI
    result = run_cli_command("-o", "json", "config", "get-contexts")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Parse JSON output
    data = JSON.parse(result[:stdout])
    assert_kind_of Array, data
    assert_equal 2, data.size

    # Check context structure
    context = data.find { |c| c["name"] == "prod" }
    assert context, "prod context not found in JSON output"
    assert_equal "production", context["cluster"]
    assert_equal "admin-prod", context["user"]
  end

  def test_get_contexts_yaml_output
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: Global flags like -o must come before the command in GLI
    result = run_cli_command("-o", "yaml", "config", "get-contexts")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Parse YAML output
    data = YAML.safe_load(result[:stdout])
    assert_kind_of Array, data
    assert_equal 2, data.size
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
