# frozen_string_literal: true

require "test_helper"

class ArgvPreprocessorTest < Minitest::Test
  # Test suite for Pvectl::ArgvPreprocessor
  # Tests preprocessing of ARGV to reorder flags before positional arguments.

  # ============================================================================
  # Basic (no transformation needed)
  # ============================================================================

  def test_no_flags
    argv = %w[get vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm], result
  end

  def test_flags_already_at_start
    argv = %w[-o wide get vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  # ============================================================================
  # Global flag extraction
  # ============================================================================

  def test_short_flag_with_space
    argv = %w[get vm -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  def test_short_flag_with_equals
    argv = %w[get vm -o=wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o=wide get vm], result
  end

  def test_long_flag_with_space
    argv = %w[get vm --output wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[--output wide get vm], result
  end

  def test_long_flag_with_equals
    argv = %w[get vm --output=wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[--output=wide get vm], result
  end

  def test_switch_flag
    argv_short = %w[get vm -v]
    result_short = Pvectl::ArgvPreprocessor.process(argv_short)
    assert_equal %w[-v get vm], result_short

    argv_long = %w[get vm --verbose]
    result_long = Pvectl::ArgvPreprocessor.process(argv_long)
    assert_equal %w[--verbose get vm], result_long
  end

  def test_multiple_global_flags
    argv = %w[describe vm -v 100 -o yaml -c /path/to/config]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-v -o yaml -c /path/to/config describe vm 100], result
  end

  def test_flags_in_middle
    argv = %w[get -o wide vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  # ============================================================================
  # Global flag duplicates
  # ============================================================================

  def test_duplicate_same_value_ok
    argv = %w[-o json get vm -o json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o json -o json get vm], result
  end

  def test_duplicate_different_value_error
    argv = %w[-o json get vm -o wide]
    error = assert_raises(Pvectl::ArgvPreprocessor::DuplicateFlagError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Duplicate global flag --output/, error.message)
    assert_match(/json/, error.message)
    assert_match(/wide/, error.message)
  end

  def test_duplicate_switch_ok
    argv = %w[-v get vm -v]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-v -v get vm], result
  end

  # ============================================================================
  # Passthrough
  # ============================================================================

  def test_help_not_processed
    argv = %w[get vm --help -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm --help -o wide], result

    argv_short = %w[get vm -h]
    result_short = Pvectl::ArgvPreprocessor.process(argv_short)
    assert_equal %w[get vm -h], result_short
  end

  def test_version_not_processed
    argv = %w[--version -o json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[--version -o json], result
  end

  # ============================================================================
  # Separator (--)
  # ============================================================================

  def test_double_dash_stops_processing
    argv = %w[get -- -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get -- -o wide], result

    argv_mixed = %w[get -v -- -o wide --verbose]
    result_mixed = Pvectl::ArgvPreprocessor.process(argv_mixed)
    assert_equal %w[-v get -- -o wide --verbose], result_mixed
  end

  # ============================================================================
  # Edge cases
  # ============================================================================

  def test_empty_argv
    argv = []
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal [], result
  end

  def test_only_command
    argv = %w[get]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get], result
  end

  def test_unknown_flag_ignored
    argv = %w[get vm --unknown-flag value]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm --unknown-flag value], result
  end

  def test_original_argv_not_mutated
    original = %w[get vm -o wide]
    original_copy = original.dup
    Pvectl::ArgvPreprocessor.process(original)
    assert_equal original_copy, original
  end
end

class ArgvPreprocessorCommandFlagReorderTest < Minitest::Test
  # Tests for reordering command flags placed after positional arguments.

  def test_delete_yes_after_positional_args
    argv = %w[delete vm 103 --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[delete --yes vm 103], result
  end

  def test_delete_force_and_yes_after_positional_args
    argv = %w[delete vm 103 --force --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[delete --force --yes vm 103], result
  end

  def test_stop_async_and_timeout_after_positional_args
    argv = %w[stop vm 100 101 --async --timeout 30]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[stop --async --timeout 30 vm 100 101], result
  end

  def test_get_node_flag_after_resource_type
    argv = %w[get vms --node pve1]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get --node pve1 vms], result
  end

  def test_template_force_after_positional_args
    # template command has --force switch but not --yes
    argv = %w[template vm 100 --force]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[template --force vm 100], result
  end

  def test_combined_global_and_command_flags_after_positional_args
    argv = %w[delete vm 103 --yes -o json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o json delete --yes vm 103], result
  end

  def test_short_flags_after_positional_args
    argv = %w[delete vm 103 -y -f]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[delete -y -f vm 103], result
  end

  def test_selector_flag_after_positional_args
    argv = %w[stop vm -l status=running --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[stop -l status=running --yes vm], result
  end

  def test_command_flags_with_double_dash_separator
    argv = %w[delete vm 103 -- --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[delete vm 103 -- --yes], result
  end

  def test_migrate_flags_after_positional_args
    argv = %w[migrate vm 100 --target pve2 --online --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[migrate --target pve2 --online --yes vm 100], result
  end

  def test_flags_already_before_positional_args
    argv = %w[delete --yes vm 103]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[delete --yes vm 103], result
  end

  def test_create_flags_after_positional_args
    argv = %w[create vm 100 --cores 4 --memory 8192 --yes]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[create --cores 4 --memory 8192 --yes vm 100], result
  end
end

class ArgvPreprocessorSubcommandFlagsTest < Minitest::Test
  # Tests for subcommand flag reordering (e.g., config set-cluster)

  def test_set_cluster_flags_after_name_reordered
    argv = %w[config set-cluster test-pve --server https://192.168.1.100:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server https://192.168.1.100:8006 test-pve], result
  end

  def test_set_cluster_switch_after_name_reordered
    argv = %w[config set-cluster test-pve --insecure-skip-tls-verify]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --insecure-skip-tls-verify test-pve], result
  end

  def test_set_cluster_multiple_flags_after_name
    argv = %w[config set-cluster test-pve --insecure-skip-tls-verify --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --insecure-skip-tls-verify --server https://pve.local:8006 test-pve], result
  end

  def test_set_cluster_flags_with_equals
    argv = %w[config set-cluster test-pve --server=https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server=https://pve.local:8006 test-pve], result
  end

  def test_set_cluster_flags_before_name_unchanged
    argv = %w[config set-cluster --server https://pve.local:8006 test-pve]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server https://pve.local:8006 test-pve], result
  end

  def test_set_credentials_flags_after_name_reordered
    argv = %w[config set-credentials admin --token-id root@pam!tok --token-secret xxx-xxx]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-credentials --token-id root@pam!tok --token-secret xxx-xxx admin], result
  end

  def test_set_context_flags_after_name_reordered
    argv = %w[config set-context prod --cluster production --user admin]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-context --cluster production --user admin prod], result
  end

  def test_global_and_subcommand_flags_combined
    argv = %w[config set-cluster test-pve --server https://pve.local:8006 -v]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-v config set-cluster --server https://pve.local:8006 test-pve], result
  end

  def test_global_flags_at_end_with_subcommand_flags
    argv = %w[config set-cluster test-pve --server https://pve.local:8006 --output json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[--output json config set-cluster --server https://pve.local:8006 test-pve], result
  end

  def test_unknown_subcommand_flags_stay_in_place
    argv = %w[config set-cluster test-pve --unknown-flag value]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster test-pve --unknown-flag value], result
  end

  def test_help_flag_passthrough
    argv = %w[config set-cluster --help test-pve --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal argv, result
  end

  def test_double_dash_stops_subcommand_processing
    argv = %w[config set-cluster test-pve -- --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster test-pve -- --server https://pve.local:8006], result
  end
end

class ArgvPreprocessorDuplicateFlagErrorTest < Minitest::Test
  def test_error_inherits_from_pvectl_error
    error = Pvectl::ArgvPreprocessor::DuplicateFlagError.new(:output, "json", "wide")
    assert_kind_of Pvectl::Error, error
  end

  def test_error_message_format
    error = Pvectl::ArgvPreprocessor::DuplicateFlagError.new(:output, "json", "wide")
    assert_equal "Duplicate global flag --output with different values: json, wide", error.message
  end
end

class ArgvPreprocessorConstantsTest < Minitest::Test
  def test_passthrough_flags_is_frozen
    assert Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS.frozen?
  end

  def test_passthrough_flags_includes_help
    flags = Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS
    assert_includes flags, "--help"
    assert_includes flags, "-h"
  end

  def test_passthrough_flags_includes_version
    flags = Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS
    assert_includes flags, "--version"
  end

  def test_max_arguments_constant
    assert_equal 10_000, Pvectl::ArgvPreprocessor::MAX_ARGUMENTS
  end

  def test_max_argument_length_constant
    assert_equal 4096, Pvectl::ArgvPreprocessor::MAX_ARGUMENT_LENGTH
  end
end

class ArgvPreprocessorSecurityTest < Minitest::Test
  def test_too_many_arguments_raises_error
    argv = Array.new(10_001) { "arg" }
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Too many arguments/, error.message)
    assert_match(/10000/, error.message)
  end

  def test_argument_too_long_raises_error
    long_arg = "a" * 4097
    argv = ["get", "vm", "-o", long_arg]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Argument too long/, error.message)
    assert_match(/4096/, error.message)
  end

  def test_missing_value_for_flag_raises_error
    argv = %w[get vm -o]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/-o/, error.message)
  end

  def test_missing_value_for_long_flag_raises_error
    argv = %w[get vm --output]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/--output/, error.message)
  end

  def test_missing_value_for_config_flag_raises_error
    argv = %w[get vm -c]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/-c/, error.message)
  end

  def test_null_byte_in_value_raises_error
    value_with_null = "json\x00malicious"
    argv = ["get", "vm", "-o", value_with_null]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
    assert_match(/--output/, error.message)
  end

  def test_null_byte_in_config_value_raises_error
    value_with_null = "/path\x00/malicious"
    argv = ["get", "vm", "-c", value_with_null]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
    assert_match(/--config/, error.message)
  end

  def test_null_byte_in_equals_format_raises_error
    value_with_null = "json\x00malicious"
    argv = ["get", "vm", "-o=#{value_with_null}"]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
  end

  def test_arguments_at_limit_ok
    argv = Array.new(10_000) { "arg" }
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal 10_000, result.length
  end

  def test_argument_length_at_limit_ok
    long_arg = "a" * 4096
    argv = ["get", "vm", long_arg]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_includes result, long_arg
  end
end
