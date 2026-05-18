# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Cloudinit Regenerate Command Tests
# =============================================================================

class CloudinitRegenerateCommandTest < Minitest::Test
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

  # ---------------------------
  # Registration
  # ---------------------------

  def test_cloudinit_command_is_registered
    assert Pvectl::CLI.commands.key?(:cloudinit), "cloudinit command should be defined"
  end

  def test_cloudinit_has_regenerate_subcommand
    cmd = Pvectl::CLI.commands[:cloudinit]
    assert cmd.commands.key?(:regenerate), "regenerate subcommand should be defined"
  end

  # ---------------------------
  # Execution
  # ---------------------------

  def test_regenerate_vm_calls_service_and_prints_ok
    path = setup_config

    fake_service = Object.new
    captured_vmid = nil
    fake_service.define_singleton_method(:regenerate) do |vmid, **_kwargs|
      captured_vmid = vmid
      { vmid: vmid, node: "pve1" }
    end

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "regenerate", "vm", "100")
        assert_equal 0, result[:exit_code], "expected success: #{result[:stderr]}"
        assert_equal 100, captured_vmid
        assert_match(/cloud-init.*regenerated|regenerated.*100/i, result[:stdout])
      end
    end
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_regenerate_missing_resource_type_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "regenerate")
    refute_equal 0, result[:exit_code]
  end

  def test_regenerate_unknown_resource_type_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "regenerate", "ct", "200")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
    assert_match(/unknown|invalid/i, result[:stderr])
  end

  def test_regenerate_missing_vmid_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "regenerate", "vm")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
  end

  def test_regenerate_returns_not_found_when_vm_missing
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:regenerate) do |_vmid, **_kw|
      raise Pvectl::ResourceNotFoundError, "VM 999 not found"
    end

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "regenerate", "vm", "999")
        assert_equal Pvectl::ExitCodes::NOT_FOUND, result[:exit_code]
        assert_match(/not found/i, result[:stderr])
      end
    end
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
