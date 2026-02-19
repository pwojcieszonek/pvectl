# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"
require "fileutils"

# =============================================================================
# Config::Wizard Tests - Availability Check
# =============================================================================

class ConfigWizardAvailabilityTest < Minitest::Test
  # Test TTY detection for wizard availability

  def test_wizard_class_exists
    assert_kind_of Class, Pvectl::Config::Wizard
  end

  def test_available_returns_true_when_stdin_is_tty
    # Mock $stdin.tty? to return true
    original_stdin = $stdin

    tty_mock = Minitest::Mock.new
    tty_mock.expect(:tty?, true)

    $stdin = tty_mock
    begin
      assert Pvectl::Config::Wizard.available?
    ensure
      $stdin = original_stdin
    end

    tty_mock.verify
  end

  def test_available_returns_false_when_stdin_is_not_tty
    # When stdin is a pipe or file, not a TTY
    original_stdin = $stdin

    non_tty_mock = Minitest::Mock.new
    non_tty_mock.expect(:tty?, false)

    $stdin = non_tty_mock
    begin
      refute Pvectl::Config::Wizard.available?
    ensure
      $stdin = original_stdin
    end

    non_tty_mock.verify
  end
end

# =============================================================================
# Config::Wizard Tests - Initialization
# =============================================================================

class ConfigWizardInitializationTest < Minitest::Test
  # Test wizard initialization

  def test_wizard_accepts_custom_prompt
    mock_prompt = Minitest::Mock.new
    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)

    assert wizard
  end

  def test_wizard_can_be_initialized_without_prompt
    # Should use default TTY::Prompt if available, or fallback
    wizard = Pvectl::Config::Wizard.new

    assert wizard
  end
end

# =============================================================================
# Config::Wizard Tests - Run Method
# =============================================================================

class ConfigWizardRunTest < Minitest::Test
  # Test the interactive wizard flow

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_wizard_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_run_returns_configuration_hash
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    assert_kind_of Hash, result
  end

  def test_run_prompts_for_server
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    cluster = result["clusters"].first
    assert_equal "https://pve.example.com:8006", cluster["cluster"]["server"]
  end

  def test_run_prompts_for_token_auth
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    user = result["users"].first
    assert_equal "root@pam!token", user["user"]["token-id"]
    assert_equal "secret-uuid", user["user"]["token-secret"]
  end

  def test_run_prompts_for_password_auth
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :password,
      username: "root@pam",
      password: "secret",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    user = result["users"].first
    assert_equal "root@pam", user["user"]["username"]
    assert_equal "secret", user["user"]["password"]
  end

  def test_run_prompts_for_ssl_verification
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: false,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    cluster = result["clusters"].first
    assert_equal true, cluster["cluster"]["insecure-skip-tls-verify"]
  end

  def test_run_sets_context_name
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "production"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    context = result["contexts"].first
    assert_equal "production", context["name"]
  end

  def test_run_sets_current_context
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "production"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    assert_equal "production", result["current-context"]
  end

  def test_run_includes_api_version
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)
    result = wizard.run

    assert_equal "pvectl/v1", result["apiVersion"]
    assert_equal "Config", result["kind"]
  end
end

# =============================================================================
# Config::Wizard Tests - Input Validation
# =============================================================================

class ConfigWizardValidationTest < Minitest::Test
  # Test input validation in wizard

  def test_wizard_validates_server_url_format
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)

    # Test validation method if exposed
    if wizard.respond_to?(:valid_server_url?, true)
      assert wizard.send(:valid_server_url?, "https://pve.example.com:8006")
      assert wizard.send(:valid_server_url?, "https://192.168.1.1:8006")
      refute wizard.send(:valid_server_url?, "not-a-url")
      refute wizard.send(:valid_server_url?, "ftp://pve.example.com")
    else
      skip "Server URL validation not exposed"
    end
  end

  def test_wizard_validates_token_id_format
    mock_prompt = MockPrompt.new(
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret-uuid",
      verify_ssl: true,
      context_name: "default"
    )

    wizard = Pvectl::Config::Wizard.new(prompt: mock_prompt)

    if wizard.respond_to?(:valid_token_id?, true)
      assert wizard.send(:valid_token_id?, "root@pam!tokenid")
      assert wizard.send(:valid_token_id?, "user@pve!api")
      refute wizard.send(:valid_token_id?, "invalid")
    else
      skip "Token ID validation not exposed"
    end
  end
end

# =============================================================================
# Mock Prompt for Testing
# =============================================================================

class MockPrompt
  # Simple mock for TTY::Prompt that returns predefined answers

  def initialize(answers)
    @answers = answers
  end

  def ask(question, **_options)
    case question
    when /server|host/i
      @answers[:server]
    when /token.*id/i
      @answers[:token_id]
    when /token.*secret/i
      @answers[:token_secret]
    when /username/i
      @answers[:username]
    when /password/i
      @answers[:password]
    when /context.*name|name.*context/i
      @answers[:context_name]
    else
      "default_answer"
    end
  end

  def select(question, choices, **_options)
    case question
    when /auth|authentication/i
      @answers[:auth_type]
    else
      choices.first
    end
  end

  def yes?(question, **_options)
    case question
    when /ssl|verify|tls/i
      @answers[:verify_ssl]
    else
      true
    end
  end

  def mask(question, **_options)
    case question
    when /token.*secret/i
      @answers[:token_secret]
    when /password/i
      @answers[:password]
    else
      "masked_input"
    end
  end

  def ok(message)
    # No-op for success messages
  end

  def warn(message)
    # No-op for warning messages
  end

  def error(message)
    # No-op for error messages
  end
end
