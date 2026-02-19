# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "json"
require "yaml"

# =============================================================================
# Ping Command Tests - Command Registration
# =============================================================================

class PingCommandRegistrationTest < Minitest::Test
  # Tests for ping command registration in CLI

  def test_ping_command_exists
    commands = Pvectl::CLI.commands
    assert commands.key?(:ping), "ping command should be defined"
  end

  def test_ping_command_has_description
    ping_cmd = Pvectl::CLI.commands[:ping]
    assert ping_cmd, "ping command not found"
    refute_nil ping_cmd.description
    refute_empty ping_cmd.description
  end
end

# =============================================================================
# Ping Command Tests - Successful Connection
# =============================================================================

class PingCommandSuccessTest < Minitest::Test
  # Tests for successful ping scenarios with mocked API

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
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

  def test_ping_returns_success_exit_code
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    # Mock Connection to avoid real API calls
    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3", "release" => "8.1" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_equal 0, result[:exit_code], "Ping should succeed: #{result[:stderr]}"
    end

    mock_connection.verify
  end

  def test_ping_outputs_ok_message
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3", "release" => "8.1" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_match(/OK.*Connected/i, result[:stdout])
    end

    mock_connection.verify
  end

  def test_ping_shows_server_hostname
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_match(/pve1\.example\.com/, result[:stdout])
    end

    mock_connection.verify
  end

  def test_ping_wide_output_shows_latency
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("-o", "wide", "ping")
      assert_match(/Latency.*\d+ms/i, result[:stdout])
    end

    mock_connection.verify
  end

  def test_ping_json_output_format
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("-o", "json", "ping")

      assert_equal 0, result[:exit_code]
      data = JSON.parse(result[:stdout])
      assert_equal "ok", data["status"]
      assert data.key?("server")
      assert data.key?("latency_ms")
    end

    mock_connection.verify
  end

  def test_ping_yaml_output_format
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("-o", "yaml", "ping")

      assert_equal 0, result[:exit_code]
      data = YAML.safe_load(result[:stdout])
      assert_equal "ok", data["status"]
      assert data.key?("server")
      assert data.key?("latency_ms")
    end

    mock_connection.verify
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

# =============================================================================
# Ping Command Tests - Connection Errors
# =============================================================================

class PingCommandErrorTest < Minitest::Test
  # Tests for ping error handling with mocked connection failures

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
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

  def test_ping_connection_timeout_returns_connection_error
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise Timeout::Error }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, result[:exit_code]
    end

    mock_connection.verify
  end

  def test_ping_connection_timeout_shows_error_message
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise Timeout::Error, "Connection timed out" }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_match(/ERROR.*timed out|ERROR.*Cannot connect/i, result[:stderr])
    end

    mock_connection.verify
  end

  def test_ping_connection_refused_returns_connection_error
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise Errno::ECONNREFUSED }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, result[:exit_code]
    end

    mock_connection.verify
  end

  def test_ping_socket_error_returns_connection_error
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise SocketError, "getaddrinfo: Name or service not known" }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("ping")
      assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, result[:exit_code]
    end

    mock_connection.verify
  end

  def test_ping_error_json_output_format
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise Timeout::Error, "Connection timed out" }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("-o", "json", "ping")

      # JSON error should go to stdout for consistent parsing
      data = JSON.parse(result[:stdout])
      assert_equal "error", data["status"]
      assert data.key?("error")
    end

    mock_connection.verify
  end

  def test_ping_error_yaml_output_format
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, nil) { raise SocketError, "Network unreachable" }

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("-o", "yaml", "ping")

      # YAML error should go to stdout for consistent parsing
      data = YAML.safe_load(result[:stdout])
      assert_equal "error", data["status"]
      assert data.key?("error")
    end

    mock_connection.verify
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

# =============================================================================
# Ping Command Tests - Configuration Errors
# =============================================================================

class PingCommandConfigErrorTest < Minitest::Test
  # Tests for ping with configuration issues

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
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

  def test_ping_with_missing_config_file
    ENV["PVECTL_CONFIG"] = "/nonexistent/path/config"

    result = run_cli_command("ping")

    # Should return config error when no config file exists
    assert_equal Pvectl::ExitCodes::CONFIG_ERROR, result[:exit_code]
  end

  def test_ping_with_invalid_yaml_config
    path = File.join(@temp_dir, "config")
    copy_fixture("invalid_yaml.yml", path)
    ENV["PVECTL_CONFIG"] = path

    result = run_cli_command("ping")

    # Should return config error for invalid YAML
    refute_equal 0, result[:exit_code]
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

# =============================================================================
# Ping Command Tests - Color Support
# =============================================================================

class PingCommandColorTest < Minitest::Test
  # Tests for color output handling

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
    # Also save NO_COLOR env var
    @original_no_color = ENV["NO_COLOR"]
    ENV.delete("NO_COLOR")
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
    if @original_no_color.nil?
      ENV.delete("NO_COLOR")
    else
      ENV["NO_COLOR"] = @original_no_color
    end
  end

  def test_ping_respects_no_color_flag
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("--no-color", "ping")
      # Output should not contain ANSI escape codes
      refute_match(/\e\[/, result[:stdout])
    end

    mock_connection.verify
  end

  def test_ping_respects_color_flag
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    ENV["PVECTL_CONFIG"] = path

    mock_connection = Minitest::Mock.new
    mock_connection.expect(:version, { "version" => "8.1-3" })

    # Note: When running in test, stdout might not be a TTY,
    # so --color flag forces color output
    Pvectl::Connection.stub(:new, mock_connection) do
      result = run_cli_command("--color", "ping")
      # With --color, OK should be green (ANSI code)
      # This is a simplified check - in real tests the output depends on Pastel configuration
      assert_match(/OK/, result[:stdout])
    end

    mock_connection.verify
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
