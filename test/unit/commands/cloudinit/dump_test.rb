# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Cloudinit Dump Command Tests
# =============================================================================

class CloudinitDumpCommandTest < Minitest::Test
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

  def test_dump_subcommand_registered
    cmd = Pvectl::CLI.commands[:cloudinit]
    assert cmd.commands.key?(:dump), "dump subcommand should be defined"
  end

  def test_dump_vm_user_prints_yaml
    setup_config

    yaml = "#cloud-config\nuser: ubuntu\nssh_authorized_keys:\n  - ssh-rsa AAA\n"
    fake_service = Object.new
    captured = {}
    fake_service.define_singleton_method(:dump) do |vmid, type, **_kw|
      captured[:vmid] = vmid
      captured[:type] = type
      yaml
    end

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "dump", "vm", "100", "user")
        assert_equal 0, result[:exit_code], "expected success: #{result[:stderr]}"
        assert_equal 100, captured[:vmid]
        assert_equal "user", captured[:type]
        assert_includes result[:stdout], "#cloud-config"
        assert_includes result[:stdout], "user: ubuntu"
      end
    end
  end

  def test_dump_vm_network_supported
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:dump) { |_vmid, _type, **_kw| "version: 1\n" }

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "dump", "vm", "100", "network")
        assert_equal 0, result[:exit_code]
        assert_includes result[:stdout], "version: 1"
      end
    end
  end

  def test_dump_vm_meta_supported
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:dump) { |_vmid, _type, **_kw| "instance-id: vm-100\n" }

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "dump", "vm", "100", "meta")
        assert_equal 0, result[:exit_code]
        assert_includes result[:stdout], "instance-id"
      end
    end
  end

  def test_dump_invalid_type_returns_usage_error
    setup_config

    result = run_cli_command("cloudinit", "dump", "vm", "100", "invalid")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
    assert_match(/invalid|valid types|user.*network.*meta/i, result[:stderr])
  end

  def test_dump_missing_type_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "dump", "vm", "100")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
  end

  def test_dump_missing_vmid_returns_usage_error
    setup_config
    result = run_cli_command("cloudinit", "dump", "vm")
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, result[:exit_code]
  end

  def test_dump_returns_not_found_when_vm_missing
    setup_config

    fake_service = Object.new
    fake_service.define_singleton_method(:dump) do |_vmid, _type, **_kw|
      raise Pvectl::ResourceNotFoundError, "VM 999 not found"
    end

    Pvectl::Services::Cloudinit.stub(:new, fake_service) do
      Pvectl::Connection.stub(:new, Object.new) do
        result = run_cli_command("cloudinit", "dump", "vm", "999", "user")
        assert_equal Pvectl::ExitCodes::NOT_FOUND, result[:exit_code]
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
