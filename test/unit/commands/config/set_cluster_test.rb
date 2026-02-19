# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config SetCluster Command Tests
# =============================================================================

class ConfigSetClusterCommandTest < Minitest::Test
  # Tests for `pvectl config set-cluster <name> [options]` command

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

  def test_config_has_set_cluster_subcommand
    config_cmd = Pvectl::CLI.commands[:config]
    assert config_cmd, "config command not found"
    subcommands = config_cmd.commands
    assert subcommands.key?(:"set-cluster"), "set-cluster subcommand should be defined"
  end

  def test_set_cluster_has_server_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_cluster_cmd = config_cmd.commands[:"set-cluster"]
    assert set_cluster_cmd, "set-cluster command not found"

    flags = set_cluster_cmd.flags
    assert flags.key?(:server), "set-cluster should have --server flag"
  end

  def test_set_cluster_has_certificate_authority_flag
    config_cmd = Pvectl::CLI.commands[:config]
    set_cluster_cmd = config_cmd.commands[:"set-cluster"]
    assert set_cluster_cmd, "set-cluster command not found"

    flags = set_cluster_cmd.flags
    has_flag = flags.key?(:"certificate-authority") || flags.key?(:certificate_authority)
    assert has_flag, "set-cluster should have --certificate-authority flag"
  end

  def test_set_cluster_has_insecure_skip_tls_verify_switch
    config_cmd = Pvectl::CLI.commands[:config]
    set_cluster_cmd = config_cmd.commands[:"set-cluster"]
    assert set_cluster_cmd, "set-cluster command not found"

    switches = set_cluster_cmd.switches
    has_switch = switches.key?(:"insecure-skip-tls-verify") || switches.key?(:insecure_skip_tls_verify)
    assert has_switch, "set-cluster should have --insecure-skip-tls-verify switch"
  end

  # ---------------------------
  # Command Execution Tests
  # ---------------------------

  def test_set_cluster_creates_new_cluster
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-cluster",
      "--server=https://pve-staging.example.com:8006",
      "staging"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the cluster was created in file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["clusters"].find { |c| c["name"] == "staging" }
    assert staging, "staging cluster should be created"
    assert_equal "https://pve-staging.example.com:8006", staging["cluster"]["server"]
  end

  def test_set_cluster_updates_existing_cluster
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-cluster",
      "--server=https://new-server.example.com:8006",
      "production"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify the cluster was updated
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    prod = loaded["clusters"].find { |c| c["name"] == "production" }
    assert_equal "https://new-server.example.com:8006", prod["cluster"]["server"]
  end

  def test_set_cluster_with_certificate_authority
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-cluster",
      "--server=https://pve-staging.example.com:8006",
      "--certificate-authority=/path/to/new-ca.crt",
      "staging"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["clusters"].find { |c| c["name"] == "staging" }
    assert_equal "/path/to/new-ca.crt", staging["cluster"]["certificate-authority"]
  end

  def test_set_cluster_with_insecure_skip_tls_verify
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-cluster",
      "--server=https://pve-staging.example.com:8006",
      "--insecure-skip-tls-verify",
      "staging"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["clusters"].find { |c| c["name"] == "staging" }
    assert_equal true, staging["cluster"]["insecure-skip-tls-verify"]
  end

  def test_set_cluster_outputs_confirmation
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command(
      "config", "set-cluster",
      "--server=https://pve-staging.example.com:8006",
      "staging"
    )

    assert_match(/cluster.*staging|created|modified/i, result[:stdout])
  end

  def test_set_cluster_fails_without_name
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "set-cluster")

    refute_equal 0, result[:exit_code]
  end

  def test_set_cluster_fails_without_server_for_new_cluster
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("config", "set-cluster", "new-cluster")

    refute_equal 0, result[:exit_code]
    assert_match(/server.*required/i, result[:stderr])
  end

  def test_set_cluster_allows_partial_update
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Update only insecure-skip-tls-verify for existing cluster
    result = run_cli_command(
      "config", "set-cluster",
      "--insecure-skip-tls-verify",
      "production"
    )

    assert_equal 0, result[:exit_code], "Command should succeed: #{result[:stderr]}"

    # Verify server was preserved
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    prod = loaded["clusters"].find { |c| c["name"] == "production" }
    assert_equal "https://pve1.example.com:8006", prod["cluster"]["server"]
    assert_equal true, prod["cluster"]["insecure-skip-tls-verify"]
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
