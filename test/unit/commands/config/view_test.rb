# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config View Command Tests
# =============================================================================

class ConfigViewCommandTest < Minitest::Test
  # Tests for `pvectl config view` command

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

  def test_config_has_view_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:view), "view subcommand should be defined"
  end

  # ---------------------------
  # Command Execution Tests
  # ---------------------------

  def test_view_shows_configuration
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"
    assert_match(/apiVersion.*pvectl\/v1/i, result[:stdout])
    assert_match(/kind.*Config/i, result[:stdout])
  end

  def test_view_shows_clusters
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    assert_match(/clusters/i, result[:stdout])
    assert_match(/production/, result[:stdout])
    assert_match(/development/, result[:stdout])
  end

  def test_view_shows_contexts
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    assert_match(/contexts/i, result[:stdout])
    assert_match(/prod/, result[:stdout])
    assert_match(/dev/, result[:stdout])
  end

  def test_view_shows_current_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    assert_match(/current-context.*prod/i, result[:stdout])
  end

  # ---------------------------
  # Security Tests - Secret Masking
  # ---------------------------

  def test_view_masks_token_secret
    path = File.join(@temp_dir, "config")
    copy_fixture("token_auth_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    # Token secret should be masked with ********
    assert_match(/\*{8}/, result[:stdout])
    # Original secret should NOT appear in output
    refute_match(/11111111-2222-3333-4444-555555555555/, result[:stdout])
  end

  def test_view_masks_password
    path = File.join(@temp_dir, "config")
    copy_fixture("password_auth_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    # Password should be masked
    assert_match(/\*{8}/, result[:stdout])
    # Original password should NOT appear
    refute_match(/secret/, result[:stdout])
  end

  def test_view_preserves_non_secret_data
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    # Server URLs should be visible
    assert_match(/pve1\.example\.com/, result[:stdout])
    # Token ID should be visible (not secret)
    assert_match(/root@pam!pvectl/, result[:stdout])
  end

  # ---------------------------
  # Output Format Tests
  # ---------------------------

  def test_view_outputs_valid_yaml
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "view")

    # Should be valid YAML
    data = YAML.safe_load(result[:stdout])
    assert_kind_of Hash, data
    assert data.key?("apiVersion")
    assert data.key?("kind")
    assert data.key?("clusters")
    assert data.key?("users")
    assert data.key?("contexts")
    assert data.key?("current-context")
  end

  def test_view_json_output
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Note: Global flags like -o must come before the command in GLI
    result = run_cli_command("-o", "json", "config", "view")

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    data = JSON.parse(result[:stdout])
    assert_kind_of Hash, data
    assert data.key?("apiVersion")
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
