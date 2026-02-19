# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config SetCredentials Command Tests
# =============================================================================

class ConfigSetCredentialsCommandTest < Minitest::Test
  # Tests for `pvectl config set-credentials <name> [options]` command

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

  def test_config_has_set_credentials_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:"set-credentials"), "set-credentials subcommand should be defined"
  end

  def test_set_credentials_has_token_id_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_credentials_cmd = config_cmd.commands[:"set-credentials"]
    assert set_credentials_cmd, "set-credentials command not found"

    flags = set_credentials_cmd.flags
    has_flag = flags.key?(:"token-id") || flags.key?(:token_id)
    assert has_flag, "set-credentials should have --token-id flag"
  end

  def test_set_credentials_has_token_secret_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_credentials_cmd = config_cmd.commands[:"set-credentials"]
    assert set_credentials_cmd, "set-credentials command not found"

    flags = set_credentials_cmd.flags
    has_flag = flags.key?(:"token-secret") || flags.key?(:token_secret)
    assert has_flag, "set-credentials should have --token-secret flag"
  end

  def test_set_credentials_has_username_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_credentials_cmd = config_cmd.commands[:"set-credentials"]
    assert set_credentials_cmd, "set-credentials command not found"

    flags = set_credentials_cmd.flags
    assert flags.key?(:username), "set-credentials should have --username flag"
  end

  def test_set_credentials_has_password_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_credentials_cmd = config_cmd.commands[:"set-credentials"]
    assert set_credentials_cmd, "set-credentials command not found"

    flags = set_credentials_cmd.flags
    assert flags.key?(:password), "set-credentials should have --password flag"
  end

  # ---------------------------
  # Token Authentication Tests
  # ---------------------------

  def test_set_credentials_creates_user_with_token_auth
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-credentials",
      "--token-id=admin@pam!newtok",
      "--token-secret=11111111-2222-3333-4444-555555555555",
      "new-admin"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the user was created in file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    new_user = loaded["users"].find { |u| u["name"] == "new-admin" }
    assert new_user, "new-admin user should be created"
    assert_equal "admin@pam!newtok", new_user["user"]["token-id"]
    assert_equal "11111111-2222-3333-4444-555555555555", new_user["user"]["token-secret"]
  end

  def test_set_credentials_updates_existing_user_token
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-credentials",
      "--token-id=root@pam!newtoken",
      "--token-secret=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "admin-prod"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the user was updated
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    admin = loaded["users"].find { |u| u["name"] == "admin-prod" }
    assert_equal "root@pam!newtoken", admin["user"]["token-id"]
    assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", admin["user"]["token-secret"]
  end

  # ---------------------------
  # Password Authentication Tests
  # ---------------------------

  def test_set_credentials_creates_user_with_password_auth
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-credentials",
      "--username=newuser@pam",
      "--password=secretpass",
      "new-user"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the user was created in file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    new_user = loaded["users"].find { |u| u["name"] == "new-user" }
    assert new_user, "new-user should be created"
    assert_equal "newuser@pam", new_user["user"]["username"]
    assert_equal "secretpass", new_user["user"]["password"]
  end

  def test_set_credentials_updates_existing_user_password
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-credentials",
      "--username=admin@pam",
      "--password=newpassword",
      "admin-dev"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the user was updated
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    admin = loaded["users"].find { |u| u["name"] == "admin-dev" }
    assert_equal "admin@pam", admin["user"]["username"]
    assert_equal "newpassword", admin["user"]["password"]
  end

  # ---------------------------
  # Output and Error Tests
  # ---------------------------

  def test_set_credentials_outputs_confirmation
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-credentials",
      "--token-id=admin@pam!tok",
      "--token-secret=11111111-2222-3333-4444-555555555555",
      "new-admin"
    )

    assert_match(/user.*new-admin|credentials.*created|modified/i, result[:stdout])
  end

  def test_set_credentials_fails_without_name
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "set-credentials")

    refute_equal 0, result[:exit_code]
  end

  def test_set_credentials_fails_without_any_credentials_for_new_user
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "set-credentials", "new-user")

    refute_equal 0, result[:exit_code]
    assert_match(/token|password|credentials.*required/i, result[:stderr])
  end

  def test_set_credentials_fails_with_incomplete_token_auth
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Only token-id without token-secret
    result = run_cli_command(
      "config", "set-credentials",
      "--token-id=admin@pam!tok",
      "new-user"
    )

    refute_equal 0, result[:exit_code]
    assert_match(/token-secret.*required|incomplete/i, result[:stderr])
  end

  def test_set_credentials_fails_with_incomplete_password_auth
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Only username without password
    result = run_cli_command(
      "config", "set-credentials",
      "--username=admin@pam",
      "new-user"
    )

    refute_equal 0, result[:exit_code]
    assert_match(/password.*required|incomplete/i, result[:stderr])
  end

  def test_set_credentials_allows_partial_update
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Update only token-secret for existing user
    result = run_cli_command(
      "config", "set-credentials",
      "--token-secret=new-secret-value-xxxx-xxxxxxxxxxxx",
      "admin-prod"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify token-id was preserved
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    admin = loaded["users"].find { |u| u["name"] == "admin-prod" }
    assert_equal "root@pam!pvectl", admin["user"]["token-id"]
    assert_equal "new-secret-value-xxxx-xxxxxxxxxxxx", admin["user"]["token-secret"]
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
