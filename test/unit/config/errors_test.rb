# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Config::Errors Tests
# =============================================================================

class ConfigErrorsTest < Minitest::Test
  # Test that all configuration error classes are properly defined

  def test_config_error_exists
    assert_kind_of Class, Pvectl::Config::ConfigError
  end

  def test_config_error_inherits_from_standard_error
    assert Pvectl::Config::ConfigError < StandardError
  end

  def test_config_not_found_error_exists
    assert_kind_of Class, Pvectl::Config::ConfigNotFoundError
  end

  def test_config_not_found_error_inherits_from_config_error
    assert Pvectl::Config::ConfigNotFoundError < Pvectl::Config::ConfigError
  end

  def test_invalid_config_error_exists
    assert_kind_of Class, Pvectl::Config::InvalidConfigError
  end

  def test_invalid_config_error_inherits_from_config_error
    assert Pvectl::Config::InvalidConfigError < Pvectl::Config::ConfigError
  end

  def test_context_not_found_error_exists
    assert_kind_of Class, Pvectl::Config::ContextNotFoundError
  end

  def test_context_not_found_error_inherits_from_config_error
    assert Pvectl::Config::ContextNotFoundError < Pvectl::Config::ConfigError
  end

  def test_cluster_not_found_error_exists
    assert_kind_of Class, Pvectl::Config::ClusterNotFoundError
  end

  def test_cluster_not_found_error_inherits_from_config_error
    assert Pvectl::Config::ClusterNotFoundError < Pvectl::Config::ConfigError
  end

  def test_user_not_found_error_exists
    assert_kind_of Class, Pvectl::Config::UserNotFoundError
  end

  def test_user_not_found_error_inherits_from_config_error
    assert Pvectl::Config::UserNotFoundError < Pvectl::Config::ConfigError
  end

  def test_missing_credentials_error_exists
    assert_kind_of Class, Pvectl::Config::MissingCredentialsError
  end

  def test_missing_credentials_error_inherits_from_config_error
    assert Pvectl::Config::MissingCredentialsError < Pvectl::Config::ConfigError
  end
end

# =============================================================================
# Config::Errors Tests - Error Messages
# =============================================================================

class ConfigErrorMessagesTest < Minitest::Test
  # Test that errors can be raised with meaningful messages

  def test_config_not_found_with_path
    error = Pvectl::Config::ConfigNotFoundError.new("Configuration file not found: /path/to/config")
    assert_match %r{/path/to/config}, error.message
  end

  def test_invalid_config_with_details
    error = Pvectl::Config::InvalidConfigError.new("Invalid YAML: unexpected end of stream")
    assert_match(/Invalid YAML/, error.message)
  end

  def test_context_not_found_with_name
    error = Pvectl::Config::ContextNotFoundError.new("Context 'production' not found")
    assert_match(/production/, error.message)
  end

  def test_cluster_not_found_with_name
    error = Pvectl::Config::ClusterNotFoundError.new("Cluster 'main' not found in configuration")
    assert_match(/main/, error.message)
  end

  def test_user_not_found_with_name
    error = Pvectl::Config::UserNotFoundError.new("User 'admin' not found in configuration")
    assert_match(/admin/, error.message)
  end

  def test_missing_credentials_with_details
    error = Pvectl::Config::MissingCredentialsError.new(
      "No valid credentials found. Provide token_id/token_secret or username/password"
    )
    assert_match(/credentials/, error.message)
  end
end

# =============================================================================
# Config::Errors Tests - Exception Handling
# =============================================================================

class ConfigErrorHandlingTest < Minitest::Test
  # Test that errors can be caught and handled properly

  def test_catch_all_config_errors
    errors = [
      Pvectl::Config::ConfigNotFoundError,
      Pvectl::Config::InvalidConfigError,
      Pvectl::Config::ContextNotFoundError,
      Pvectl::Config::ClusterNotFoundError,
      Pvectl::Config::UserNotFoundError,
      Pvectl::Config::MissingCredentialsError
    ]

    errors.each do |error_class|
      caught = false
      begin
        raise error_class, "Test error"
      rescue Pvectl::Config::ConfigError
        caught = true
      end
      assert caught, "#{error_class} should be catchable as ConfigError"
    end
  end

  def test_config_errors_have_backtrace
    begin
      raise Pvectl::Config::ConfigNotFoundError, "Test"
    rescue Pvectl::Config::ConfigError => e
      assert e.backtrace, "Error should have backtrace"
      refute e.backtrace.empty?, "Backtrace should not be empty"
    end
  end
end
