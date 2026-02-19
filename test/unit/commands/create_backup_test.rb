# frozen_string_literal: true

require "test_helper"

class CreateBackupTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    $stderr = StringIO.new
    $stdout = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
  end

  def test_returns_usage_error_when_resource_type_nil
    exit_code = Pvectl::Commands::CreateBackup.execute(nil, [], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_resource_type_not_backup
    exit_code = Pvectl::Commands::CreateBackup.execute("snapshot", [], { storage: "local" }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_vmids
    exit_code = Pvectl::Commands::CreateBackup.execute("backup", [], { storage: "local" }, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_returns_usage_error_when_no_storage
    exit_code = Pvectl::Commands::CreateBackup.execute("backup", ["100"], {}, {})
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_error_message_includes_storage_required
    Pvectl::Commands::CreateBackup.execute("backup", ["100"], {}, {})
    assert_includes $stderr.string, "--storage is required"
  end

  def test_error_message_for_missing_resource_type
    Pvectl::Commands::CreateBackup.execute(nil, ["100"], { storage: "local" }, {})
    assert_includes $stderr.string, "Resource type required"
  end

  def test_error_message_for_unsupported_resource_type
    Pvectl::Commands::CreateBackup.execute("snapshot", ["100"], { storage: "local" }, {})
    assert_includes $stderr.string, "Unsupported resource"
  end

  def test_error_message_for_missing_vmids
    Pvectl::Commands::CreateBackup.execute("backup", [], { storage: "local" }, {})
    assert_includes $stderr.string, "At least one VMID is required"
  end

  def test_class_has_supported_resources_constant
    assert_equal %w[backup], Pvectl::Commands::CreateBackup::SUPPORTED_RESOURCES
  end

  def test_initializes_with_array_of_resource_ids
    cmd = Pvectl::Commands::CreateBackup.new("backup", %w[100 101], { storage: "local" }, {})
    assert_equal [100, 101], cmd.instance_variable_get(:@resource_ids)
  end

  def test_initializes_with_single_resource_id_converted_to_array
    cmd = Pvectl::Commands::CreateBackup.new("backup", "100", { storage: "local" }, {})
    assert_equal [100], cmd.instance_variable_get(:@resource_ids)
  end

  def test_initializes_with_nil_resource_id_as_empty_array
    cmd = Pvectl::Commands::CreateBackup.new("backup", nil, { storage: "local" }, {})
    assert_equal [], cmd.instance_variable_get(:@resource_ids)
  end
end

class CreateBackupConfirmationTest < Minitest::Test
  # Test helper class to expose private methods for testing
  class TestableCreateBackup < Pvectl::Commands::CreateBackup
    # Expose private method for testing
    def test_confirm_operation
      confirm_operation
    end
  end

  def setup
    @original_stdin = $stdin
    @original_stdout = $stdout
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stdin = @original_stdin
    $stdout = @original_stdout
    $stderr = @original_stderr
  end

  def test_skips_confirmation_for_single_vmid
    cmd = TestableCreateBackup.new("backup", ["100"], { storage: "local" }, {})
    result = cmd.test_confirm_operation
    assert result, "Single VMID should not require confirmation"
  end

  def test_skips_confirmation_with_yes_flag
    cmd = TestableCreateBackup.new("backup", %w[100 101], { storage: "local", yes: true }, {})
    result = cmd.test_confirm_operation
    assert result, "--yes flag should skip confirmation"
  end

  def test_confirms_multi_vmid_operation_with_y_response
    cmd = TestableCreateBackup.new("backup", %w[100 101], { storage: "local" }, {})

    $stdin = StringIO.new("y\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    assert result, "Should proceed with 'y' response"
  end

  def test_aborts_multi_vmid_operation_with_n_response
    cmd = TestableCreateBackup.new("backup", %w[100 101], { storage: "local" }, {})

    $stdin = StringIO.new("n\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    refute result, "Should abort with 'n' response"
  end

  def test_aborts_multi_vmid_operation_with_empty_response
    cmd = TestableCreateBackup.new("backup", %w[100 101], { storage: "local" }, {})

    $stdin = StringIO.new("\n")
    $stdout = StringIO.new

    result = cmd.test_confirm_operation
    refute result, "Should abort with empty response (default No)"
  end

  def test_confirmation_prompt_format
    cmd = TestableCreateBackup.new("backup", %w[100 101 102], { storage: "nfs" }, {})

    $stdin = StringIO.new("n\n")
    output = StringIO.new
    $stdout = output

    cmd.test_confirm_operation
    output_str = output.string

    assert_includes output_str, "You are about to create backups"
    assert_includes output_str, "3 VMs"
    assert_includes output_str, "100"
    assert_includes output_str, "101"
    assert_includes output_str, "102"
    assert_includes output_str, "Proceed? [y/N]:"
  end
end
