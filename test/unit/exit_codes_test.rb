# frozen_string_literal: true

require "test_helper"

class ExitCodesTest < Minitest::Test
  # Test that all exit code constants are defined as per ARCHITECTURE.md section 6.1

  def test_success_code_is_defined
    assert_equal 0, Pvectl::ExitCodes::SUCCESS
  end

  def test_general_error_code_is_defined
    assert_equal 1, Pvectl::ExitCodes::GENERAL_ERROR
  end

  def test_usage_error_code_is_defined
    assert_equal 2, Pvectl::ExitCodes::USAGE_ERROR
  end

  def test_config_error_code_is_defined
    assert_equal 3, Pvectl::ExitCodes::CONFIG_ERROR
  end

  def test_connection_error_code_is_defined
    assert_equal 4, Pvectl::ExitCodes::CONNECTION_ERROR
  end

  def test_not_found_code_is_defined
    assert_equal 5, Pvectl::ExitCodes::NOT_FOUND
  end

  def test_permission_denied_code_is_defined
    assert_equal 6, Pvectl::ExitCodes::PERMISSION_DENIED
  end

  def test_interrupted_code_is_defined
    assert_equal 130, Pvectl::ExitCodes::INTERRUPTED
  end

  def test_exit_codes_module_is_frozen
    # ExitCodes should be a module with frozen constants
    assert_kind_of Module, Pvectl::ExitCodes
  end

  def test_all_exit_codes_are_integers
    constants = Pvectl::ExitCodes.constants
    constants.each do |const|
      value = Pvectl::ExitCodes.const_get(const)
      assert_kind_of Integer, value, "#{const} should be an Integer"
    end
  end

  def test_expected_number_of_exit_codes
    # 8 exit codes: SUCCESS, GENERAL_ERROR, USAGE_ERROR, CONFIG_ERROR,
    # CONNECTION_ERROR, NOT_FOUND, PERMISSION_DENIED, INTERRUPTED
    assert_equal 8, Pvectl::ExitCodes.constants.size
  end
end
