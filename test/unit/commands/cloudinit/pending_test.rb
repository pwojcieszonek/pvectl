# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "json"

# =============================================================================
# Cloudinit Pending Command Tests
# =============================================================================

class CloudinitPendingCommandTest < Minitest::Test
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
      value.nil? ? ENV.delete(var) : ENV[var] = value
    end
  end

  def test_pending_subcommand_registered
    cmd = Pvectl::CLI.commands[:cloudinit]
    assert cmd.commands.key?(:pending), "pending subcommand should be defined"
  end

  def test_pending_vm_prints_table_of_changes
    setup_config

    entries = [
      { key: "user", value: "ubuntu", pending: "admin" },
      { key: "password", delete: 1 },
      { key: "ipconfig0", pending: "ip=10.0.0.10/24,gw=10.0.0.1" }
    ]
    fake_service = Object.new
    fake_service.define_singleton_method(:pending) { |_vmid, **_kw| entries }

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "pending", "vm", "100")
        assert_equal 0, result[:exit_code], "expected success: #{result[:stderr]}"
        assert_match(/user/i, result[:stdout])
        assert_match(/password/i, result[:stdout])
        assert_match(/ipconfig0/i, result[:stdout])
      end
    end
  end

  def test_pending_vm_with_json_output
    setup_config

    entries = [{ key: "user", value: "ubuntu", pending: "admin" }]
    fake_service = Object.new
    fake_service.define_singleton_method(:pending) { |_vmid, **_kw| entries }

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("-o", "json", "cloudinit", "pending", "vm", "100")
        assert_equal 0, result[:exit_code]
        # JSON output should be parseable and contain the entries
        data = JSON.parse(result[:stdout])
        assert_kind_of Array, data
        assert_equal "user", data.first["key"]
      end
    end
  end

  def test_pending_vm_with_no_changes_prints_friendly_message
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:pending) { |_vmid, **_kw| [] }

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "pending", "vm", "100")
        assert_equal 0, result[:exit_code]
        assert_match(/no pending|no changes/i, result[:stdout])
      end
    end
  end

  def test_pending_returns_not_found_when_vm_missing
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:pending) do |_vmid, **_kw|
      raise Pvectl::ResourceNotFoundError, "VM 999 not found"
    end

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "pending", "vm", "999")
        assert_equal Pvectl::ExitCodes::NOT_FOUND, result[:exit_code]
      end
    end
  end

  def test_pending_missing_vmid_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "pending", "vm")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
  end

  private

  def setup_config
    path = File.join(@temp_dir, "config")
    FileUtils.cp(File.join(@fixtures_path, "valid_config.yml"), path)
    File.chmod(0o600, path)
    ENV["PVECTL_CONFIG"] = path
    path
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
    out = $stdout.string
    err = $stderr.string
    $stdout = old_stdout
    $stderr = old_stderr
    { exit_code: exit_code || 0, stdout: out, stderr: err }
  end
end
