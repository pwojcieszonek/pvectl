# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  # Test that CLI class exists and has proper GLI configuration

  def test_cli_class_exists
    assert_kind_of Class, Pvectl::CLI
  end

  def test_cli_extends_gli_app
    assert Pvectl::CLI.singleton_class.ancestors.include?(GLI::App),
           "CLI should extend GLI::App"
  end

  def test_cli_run_method_is_defined
    assert_respond_to Pvectl::CLI, :run
  end

  def test_cli_version_matches_pvectl_version
    # GLI stores version as class variable/method
    # Check that version is properly configured
    assert_respond_to Pvectl::CLI, :version_string
    assert_includes Pvectl::CLI.version_string, Pvectl::VERSION
  end

  def test_cli_has_program_description
    # GLI stores program_desc as instance variable
    desc = Pvectl::CLI.instance_variable_get(:@program_desc)
    assert desc, "program_desc should be set"
    assert_match(/proxmox/i, desc.to_s)
  end
end

class CLIGlobalFlagsTest < Minitest::Test
  # Test that global flags are properly configured

  def setup
    @flags = Pvectl::CLI.flags
    @switches = Pvectl::CLI.switches
  end

  # --output / -o flag tests

  def test_output_flag_is_defined
    assert @flags.key?(:output) || @flags.key?(:o),
           "Output flag should be defined"
  end

  def test_output_flag_has_short_option
    output_flag = @flags[:output] || @flags[:o]
    assert output_flag, "Output flag not found"
    aliases = [output_flag.name, output_flag.aliases].flatten
    assert aliases.include?(:o) || aliases.include?(:output),
           "Output flag should have -o short option"
  end

  def test_output_flag_default_is_table
    output_flag = @flags[:output] || @flags[:o]
    assert output_flag, "Output flag not found"
    assert_equal "table", output_flag.default_value
  end

  def test_output_flag_must_match_valid_formats
    output_flag = @flags[:output] || @flags[:o]
    assert output_flag, "Output flag not found"

    # GLI uses must_match for validation
    valid_formats = %w[table json yaml wide]
    must_match = output_flag.must_match

    assert must_match, "Output flag should have must_match validation"

    valid_formats.each do |format|
      assert must_match.include?(format),
             "Output flag should accept '#{format}'"
    end
  end

  # --verbose / -v switch tests

  def test_verbose_switch_is_defined
    assert @switches.key?(:verbose) || @switches.key?(:v),
           "Verbose switch should be defined"
  end

  def test_verbose_switch_has_short_option
    verbose_switch = @switches[:verbose] || @switches[:v]
    assert verbose_switch, "Verbose switch not found"
    aliases = [verbose_switch.name, verbose_switch.aliases].flatten
    assert aliases.include?(:v) || aliases.include?(:verbose),
           "Verbose switch should have -v short option"
  end

  def test_verbose_switch_is_not_negatable
    verbose_switch = @switches[:verbose] || @switches[:v]
    assert verbose_switch, "Verbose switch not found"
    # Switch should be negatable: false
    refute verbose_switch.negatable,
           "Verbose switch should not be negatable"
  end

  # --config / -c flag tests

  def test_config_flag_is_defined
    assert @flags.key?(:config) || @flags.key?(:c),
           "Config flag should be defined"
  end

  def test_config_flag_has_short_option
    config_flag = @flags[:config] || @flags[:c]
    assert config_flag, "Config flag not found"
    aliases = [config_flag.name, config_flag.aliases].flatten
    assert aliases.include?(:c) || aliases.include?(:config),
           "Config flag should have -c short option"
  end

  def test_config_flag_has_no_default
    config_flag = @flags[:config] || @flags[:c]
    assert config_flag, "Config flag not found"
    assert_nil config_flag.default_value,
               "Config flag should have no default value"
  end
end

class CLIOutputValidationTest < Minitest::Test
  # Test output format validation

  def test_valid_output_formats
    valid_formats = %w[table json yaml wide]
    valid_formats.each do |format|
      # This test verifies the configuration matches expected formats
      output_flag = Pvectl::CLI.flags[:output] || Pvectl::CLI.flags[:o]
      assert output_flag.must_match.include?(format),
             "Format '#{format}' should be valid"
    end
  end

  def test_invalid_output_format_not_in_must_match
    output_flag = Pvectl::CLI.flags[:output] || Pvectl::CLI.flags[:o]
    invalid_formats = %w[csv xml html text]

    invalid_formats.each do |format|
      refute output_flag.must_match.include?(format),
             "Format '#{format}' should NOT be valid"
    end
  end
end

class CLIConfigurationTest < Minitest::Test
  # Test GLI configuration options

  def test_subcommand_option_handling_is_normal
    # Check that subcommand_option_handling is set to :normal
    # GLI stores this as @subcommand_option_handling_strategy
    handling = Pvectl::CLI.instance_variable_get(:@subcommand_option_handling_strategy)
    assert_equal :normal, handling,
                 "subcommand_option_handling should be :normal"
  end

  def test_arguments_mode_is_flexible
    # Check that arguments mode is NOT set to :strict
    # This allows kubectl-style flexible flag/argument ordering
    args_mode = Pvectl::CLI.instance_variable_get(:@argument_handling_strategy)
    assert_nil args_mode,
               "arguments mode should be nil (not strict) for flexible ordering"
  end
end

class CLIErrorHandlingTest < Minitest::Test
  # Test that error handling is configured

  def test_on_error_handler_is_defined
    # GLI stores on_error block
    error_block = Pvectl::CLI.instance_variable_get(:@error_block)
    assert error_block, "on_error handler should be defined"
  end
end
