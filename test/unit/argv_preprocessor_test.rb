# frozen_string_literal: true

require "test_helper"

class ArgvPreprocessorTest < Minitest::Test
  # Test suite for Pvectl::ArgvPreprocessor
  # Tests the preprocessing of ARGV to move global flags to the beginning
  # as specified in docs/specs/flagi-globalne.md section 5.2

  # ============================================================================
  # Podstawowe (Basic)
  # ============================================================================

  def test_no_flags
    # ARGV bez flag przechodzi bez zmian
    argv = %w[get vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm], result
  end

  def test_flags_already_at_start
    # Flagi na poczatku - brak zmian (ale normalizowane do krotkiej formy)
    argv = %w[-o wide get vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  # ============================================================================
  # Transformacja (Transformation)
  # ============================================================================

  def test_short_flag_with_space
    # -o wide -> przeniesione na poczatek
    argv = %w[get vm -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  def test_short_flag_with_equals
    # -o=wide -> przeniesione na poczatek (rozdzielone)
    argv = %w[get vm -o=wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  def test_long_flag_with_space
    # --output wide -> przeniesione na poczatek (konwertowane na krotka forme)
    argv = %w[get vm --output wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  def test_long_flag_with_equals
    # --output=wide -> przeniesione na poczatek (konwertowane na krotka forme)
    argv = %w[get vm --output=wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  def test_switch_flag
    # -v lub --verbose -> przeniesione na poczatek
    # Test short form
    argv_short = %w[get vm -v]
    result_short = Pvectl::ArgvPreprocessor.process(argv_short)
    assert_equal %w[-v get vm], result_short

    # Test long form
    argv_long = %w[get vm --verbose]
    result_long = Pvectl::ArgvPreprocessor.process(argv_long)
    assert_equal %w[-v get vm], result_long
  end

  def test_multiple_flags
    # -v -o wide -c file -> wszystkie przeniesione na poczatek
    # Flags should be in order defined in GLOBAL_FLAGS (output, verbose, config)
    argv = %w[describe vm -v 100 -o yaml -c /path/to/config]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o yaml -v -c /path/to/config describe vm 100], result
  end

  def test_flags_in_middle
    # get -o wide vm -> poprawna transformacja
    argv = %w[get -o wide vm]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o wide get vm], result
  end

  # ============================================================================
  # Duplikaty (Duplicates)
  # ============================================================================

  def test_duplicate_same_value_ok
    # -o json ... -o json -> deduplikacja (zachowane pierwsze wystapienie)
    argv = %w[-o json get vm -o json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o json get vm], result
  end

  def test_duplicate_different_value_error
    # -o json ... -o wide -> DuplicateFlagError
    argv = %w[-o json get vm -o wide]
    error = assert_raises(Pvectl::ArgvPreprocessor::DuplicateFlagError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Duplicate global flag --output/, error.message)
    assert_match(/json/, error.message)
    assert_match(/wide/, error.message)
  end

  def test_duplicate_switch_ok
    # -v ... -v -> deduplikacja
    argv = %w[-v get vm -v]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-v get vm], result
  end

  # ============================================================================
  # Passthrough
  # ============================================================================

  def test_help_not_processed
    # --help pozostaje na miejscu - ARGV zwracane bez zmian
    argv = %w[get vm --help -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm --help -o wide], result

    # Test -h short form
    argv_short = %w[get vm -h]
    result_short = Pvectl::ArgvPreprocessor.process(argv_short)
    assert_equal %w[get vm -h], result_short
  end

  def test_version_not_processed
    # --version pozostaje na miejscu - ARGV zwracane bez zmian
    argv = %w[--version -o json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[--version -o json], result
  end

  # ============================================================================
  # Separator
  # ============================================================================

  def test_double_dash_stops_processing
    # get -- -o wide -> -o wide po -- nie przetwarzane
    argv = %w[get -- -o wide]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get -- -o wide], result

    # More complex case with flags before and after --
    argv_mixed = %w[get -v -- -o wide --verbose]
    result_mixed = Pvectl::ArgvPreprocessor.process(argv_mixed)
    assert_equal %w[-v get -- -o wide --verbose], result_mixed
  end

  # ============================================================================
  # Edge cases
  # ============================================================================

  def test_empty_argv
    # [] -> []
    argv = []
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal [], result
  end

  def test_only_command
    # ["get"] -> ["get"]
    argv = %w[get]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get], result
  end

  def test_unknown_flag_ignored
    # --unknown pozostaje na miejscu
    argv = %w[get vm --unknown-flag value]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[get vm --unknown-flag value], result

    # Combined with known flags
    argv_mixed = %w[get vm -o wide --unknown value]
    result_mixed = Pvectl::ArgvPreprocessor.process(argv_mixed)
    assert_equal %w[-o wide get vm --unknown value], result_mixed
  end
end

class ArgvPreprocessorDuplicateFlagErrorTest < Minitest::Test
  # Test the DuplicateFlagError class

  def test_error_inherits_from_pvectl_error
    error = Pvectl::ArgvPreprocessor::DuplicateFlagError.new(:output, "json", "wide")
    assert_kind_of Pvectl::Error, error
  end

  def test_error_message_format
    error = Pvectl::ArgvPreprocessor::DuplicateFlagError.new(:output, "json", "wide")
    assert_equal "Duplicate global flag --output with different values: json, wide", error.message
  end
end

class ArgvPreprocessorConfigurationTest < Minitest::Test
  # Test the static configuration constants

  def test_global_flags_is_frozen
    assert Pvectl::ArgvPreprocessor::GLOBAL_FLAGS.frozen?,
           "GLOBAL_FLAGS should be frozen"
  end

  def test_global_flags_has_output
    flags = Pvectl::ArgvPreprocessor::GLOBAL_FLAGS
    assert flags.key?(:output), "GLOBAL_FLAGS should include :output"
    assert_equal "-o", flags[:output][:short]
    assert_equal "--output", flags[:output][:long]
    assert flags[:output][:has_value], "output flag should have value"
  end

  def test_global_flags_has_verbose
    flags = Pvectl::ArgvPreprocessor::GLOBAL_FLAGS
    assert flags.key?(:verbose), "GLOBAL_FLAGS should include :verbose"
    assert_equal "-v", flags[:verbose][:short]
    assert_equal "--verbose", flags[:verbose][:long]
    refute flags[:verbose][:has_value], "verbose flag should not have value"
  end

  def test_global_flags_has_config
    flags = Pvectl::ArgvPreprocessor::GLOBAL_FLAGS
    assert flags.key?(:config), "GLOBAL_FLAGS should include :config"
    assert_equal "-c", flags[:config][:short]
    assert_equal "--config", flags[:config][:long]
    assert flags[:config][:has_value], "config flag should have value"
  end

  def test_passthrough_flags_is_frozen
    assert Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS.frozen?,
           "PASSTHROUGH_FLAGS should be frozen"
  end

  def test_passthrough_flags_includes_help
    flags = Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS
    assert flags.include?("--help"), "PASSTHROUGH_FLAGS should include --help"
    assert flags.include?("-h"), "PASSTHROUGH_FLAGS should include -h"
  end

  def test_passthrough_flags_includes_version
    flags = Pvectl::ArgvPreprocessor::PASSTHROUGH_FLAGS
    assert flags.include?("--version"), "PASSTHROUGH_FLAGS should include --version"
  end
end

class ArgvPreprocessorOriginalArgvUnchangedTest < Minitest::Test
  # Test that the original ARGV is not mutated

  def test_original_argv_not_mutated
    original = %w[get vm -o wide]
    original_copy = original.dup
    Pvectl::ArgvPreprocessor.process(original)
    assert_equal original_copy, original, "Original ARGV should not be mutated"
  end
end

class ArgvPreprocessorSubcommandFlagsTest < Minitest::Test
  # Test suite for subcommand flag reordering
  # Flags after positional arguments should be moved before them

  # ============================================================================
  # config set-cluster subcommand
  # ============================================================================

  def test_set_cluster_flags_after_name_reordered
    # pvectl config set-cluster test-pve --server https://... should work
    argv = %w[config set-cluster test-pve --server https://192.168.1.100:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server https://192.168.1.100:8006 test-pve], result
  end

  def test_set_cluster_switch_after_name_reordered
    # pvectl config set-cluster test-pve --insecure-skip-tls-verify should work
    argv = %w[config set-cluster test-pve --insecure-skip-tls-verify]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --insecure-skip-tls-verify test-pve], result
  end

  def test_set_cluster_multiple_flags_after_name
    # Multiple flags after positional argument
    argv = %w[config set-cluster test-pve --insecure-skip-tls-verify --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --insecure-skip-tls-verify --server https://pve.local:8006 test-pve], result
  end

  def test_set_cluster_flags_with_equals
    # Flags using = syntax
    argv = %w[config set-cluster test-pve --server=https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server=https://pve.local:8006 test-pve], result
  end

  def test_set_cluster_flags_before_name_unchanged
    # Flags already before positional argument - no change needed
    argv = %w[config set-cluster --server https://pve.local:8006 test-pve]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster --server https://pve.local:8006 test-pve], result
  end

  # ============================================================================
  # config set-credentials subcommand
  # ============================================================================

  def test_set_credentials_flags_after_name_reordered
    argv = %w[config set-credentials admin --token-id root@pam!tok --token-secret xxx-xxx]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-credentials --token-id root@pam!tok --token-secret xxx-xxx admin], result
  end

  def test_set_credentials_password_auth_flags
    argv = %w[config set-credentials dev-user --username root@pam --password secret123]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-credentials --username root@pam --password secret123 dev-user], result
  end

  # ============================================================================
  # config set-context subcommand
  # ============================================================================

  def test_set_context_flags_after_name_reordered
    argv = %w[config set-context prod --cluster production --user admin]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-context --cluster production --user admin prod], result
  end

  # ============================================================================
  # Combined with global flags
  # ============================================================================

  def test_global_and_subcommand_flags_combined
    # Both global flags and subcommand flags after positional
    argv = %w[config set-cluster test-pve --server https://pve.local:8006 -v]
    result = Pvectl::ArgvPreprocessor.process(argv)
    # Global flags go to beginning, subcommand flags before positional
    assert_equal %w[-v config set-cluster --server https://pve.local:8006 test-pve], result
  end

  def test_global_flags_at_end_with_subcommand_flags
    argv = %w[config set-cluster test-pve --server https://pve.local:8006 --output json]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[-o json config set-cluster --server https://pve.local:8006 test-pve], result
  end

  # ============================================================================
  # Edge cases
  # ============================================================================

  def test_unknown_subcommand_flags_stay_in_place
    # Unknown flags should remain where they are (after positional)
    argv = %w[config set-cluster test-pve --unknown-flag value]
    result = Pvectl::ArgvPreprocessor.process(argv)
    # Unknown flags stay after positional argument
    assert_equal %w[config set-cluster test-pve --unknown-flag value], result
  end

  def test_help_flag_passthrough
    # --help should trigger passthrough mode
    argv = %w[config set-cluster --help test-pve --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal argv, result
  end

  def test_double_dash_stops_subcommand_processing
    # -- should stop all processing
    argv = %w[config set-cluster test-pve -- --server https://pve.local:8006]
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal %w[config set-cluster test-pve -- --server https://pve.local:8006], result
  end
end

class ArgvPreprocessorSecurityTest < Minitest::Test
  # Security tests for input validation

  def test_too_many_arguments_raises_error
    # Test DoS protection - limit on number of arguments
    argv = Array.new(10_001) { "arg" }
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Too many arguments/, error.message)
    assert_match(/10000/, error.message)
  end

  def test_argument_too_long_raises_error
    # Test DoS protection - limit on argument length
    long_arg = "a" * 4097
    argv = ["get", "vm", "-o", long_arg]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Argument too long/, error.message)
    assert_match(/4096/, error.message)
  end

  def test_missing_value_for_flag_raises_error
    # Test bounds check - flag requiring value as last argument
    argv = %w[get vm -o]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/-o/, error.message)
  end

  def test_missing_value_for_long_flag_raises_error
    # Test bounds check with long flag form
    argv = %w[get vm --output]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/--output/, error.message)
  end

  def test_missing_value_for_config_flag_raises_error
    # Test bounds check for config flag
    argv = %w[get vm -c]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Missing value for flag/, error.message)
    assert_match(/-c/, error.message)
  end

  def test_null_byte_in_value_raises_error
    # Test null byte injection protection
    value_with_null = "json\x00malicious"
    argv = ["get", "vm", "-o", value_with_null]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
    assert_match(/--output/, error.message)
  end

  def test_null_byte_in_config_value_raises_error
    # Test null byte injection protection for config flag
    value_with_null = "/path\x00/malicious"
    argv = ["get", "vm", "-c", value_with_null]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
    assert_match(/--config/, error.message)
  end

  def test_null_byte_in_equals_format_raises_error
    # Test null byte injection protection with equals format
    value_with_null = "json\x00malicious"
    argv = ["get", "vm", "-o=#{value_with_null}"]
    error = assert_raises(ArgumentError) do
      Pvectl::ArgvPreprocessor.process(argv)
    end
    assert_match(/Invalid null byte/, error.message)
  end

  def test_max_arguments_constant_exists
    assert_equal 10_000, Pvectl::ArgvPreprocessor::MAX_ARGUMENTS
  end

  def test_max_argument_length_constant_exists
    assert_equal 4096, Pvectl::ArgvPreprocessor::MAX_ARGUMENT_LENGTH
  end

  def test_arguments_at_limit_ok
    # Test that exactly MAX_ARGUMENTS is accepted
    argv = Array.new(10_000) { "arg" }
    # Should not raise
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_equal 10_000, result.length
  end

  def test_argument_length_at_limit_ok
    # Test that exactly MAX_ARGUMENT_LENGTH is accepted
    long_arg = "a" * 4096
    argv = ["get", "vm", long_arg]
    # Should not raise
    result = Pvectl::ArgvPreprocessor.process(argv)
    assert_includes result, long_arg
  end
end
