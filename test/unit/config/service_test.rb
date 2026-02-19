# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config::Service Tests - Constants and Initialization
# =============================================================================

class ConfigServiceInitializationTest < Minitest::Test
  # Test service initialization and constants

  def test_service_class_exists
    assert_kind_of Class, Pvectl::Config::Service
  end

  def test_default_config_path_constant
    expected = File.expand_path("~/.pvectl/config")
    assert_equal expected, Pvectl::Config::Service::DEFAULT_CONFIG_PATH
  end

  def test_service_accepts_custom_provider
    mock_provider = Minitest::Mock.new
    service = Pvectl::Config::Service.new(provider: mock_provider)

    assert service
  end

  def test_service_accepts_custom_store
    mock_store = Minitest::Mock.new
    service = Pvectl::Config::Service.new(store: mock_store)

    assert service
  end

  def test_service_accepts_custom_wizard
    mock_wizard = Minitest::Mock.new
    service = Pvectl::Config::Service.new(wizard: mock_wizard)

    assert service
  end
end

# =============================================================================
# Config::Service Tests - Loading Configuration
# =============================================================================

class ConfigServiceLoadTest < Minitest::Test
  # Test loading configuration through the service facade

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_load_returns_service_instance
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    result = service.load(config: path)

    assert_equal service, result
  end

  def test_load_sets_config_path
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_equal path, service.config_path
  end

  def test_load_sets_current_context_name
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_equal "prod", service.current_context_name
  end

  def test_load_with_context_override
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path, context: "dev")

    assert_equal "dev", service.current_context_name
  end

  def test_load_uses_default_path_when_not_specified
    # This test checks that when no config is specified, default path is used
    service = Pvectl::Config::Service.new
    # When config file doesn't exist at default path, it should raise
    # (unless wizard runs, but we're mocking that away)

    mock_provider = Minitest::Mock.new
    mock_provider.expect(:file_exists?, false, [Pvectl::Config::Service::DEFAULT_CONFIG_PATH])

    service_with_mock = Pvectl::Config::Service.new(provider: mock_provider)

    assert_raises(Pvectl::Config::ConfigNotFoundError) do
      service_with_mock.load({})
    end

    mock_provider.verify
  end

  def test_load_uses_env_config_path
    custom_path = File.join(@fixtures_path, "token_auth_config.yml")
    ENV["PVECTL_CONFIG"] = custom_path

    service = Pvectl::Config::Service.new
    service.load({})

    assert_equal custom_path, service.config_path
  end

  def test_load_raises_for_missing_config
    path = File.join(@temp_dir, "nonexistent.yml")
    service = Pvectl::Config::Service.new

    assert_raises(Pvectl::Config::ConfigNotFoundError) do
      service.load(config: path)
    end
  end

  def test_load_raises_for_invalid_yaml
    path = File.join(@fixtures_path, "invalid_yaml.yml")
    service = Pvectl::Config::Service.new

    assert_raises(Pvectl::Config::InvalidConfigError) do
      service.load(config: path)
    end
  end
end

# =============================================================================
# Config::Service Tests - Current Config Access
# =============================================================================

class ConfigServiceCurrentConfigTest < Minitest::Test
  # Test accessing the current resolved configuration

  def setup
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_current_config_returns_resolved_config
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    config = service.current_config

    assert_kind_of Pvectl::Config::Models::ResolvedConfig, config
  end

  def test_current_config_has_server
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_equal "https://pve1.example.com:8006", service.current_config.server
  end

  def test_current_config_has_auth_type
    path = File.join(@fixtures_path, "token_auth_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert service.current_config.token_auth?
  end

  def test_current_config_raises_before_load
    service = Pvectl::Config::Service.new

    assert_raises(Pvectl::Config::ConfigError) do
      service.current_config
    end
  end
end

# =============================================================================
# Config::Service Tests - Context Management
# =============================================================================

class ConfigServiceContextManagementTest < Minitest::Test
  # Test context listing and switching

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_contexts_returns_array
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_kind_of Array, service.contexts
  end

  def test_contexts_returns_context_models
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    service.contexts.each do |ctx|
      assert_kind_of Pvectl::Config::Models::Context, ctx
    end
  end

  def test_contexts_count
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_equal 2, service.contexts.size
  end

  def test_context_returns_specific_context
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    ctx = service.context("prod")

    assert_kind_of Pvectl::Config::Models::Context, ctx
    assert_equal "prod", ctx.name
  end

  def test_context_returns_nil_for_unknown
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_nil service.context("nonexistent")
  end

  def test_use_context_switches_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)

    service.use_context("dev")

    assert_equal "dev", service.current_context_name
  end

  def test_use_context_persists_to_file
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.use_context("dev")

    # Reload from file
    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal "dev", loaded["current-context"]
  end

  def test_use_context_raises_for_unknown_context
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    assert_raises(Pvectl::Config::ContextNotFoundError) do
      service.use_context("nonexistent")
    end
  end

  def test_set_context_creates_new_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.set_context(
      name: "staging",
      cluster: "production",
      user: "admin-prod"
    )

    ctx = service.context("staging")
    assert ctx
    assert_equal "production", ctx.cluster_ref
    assert_equal "admin-prod", ctx.user_ref
  end

  def test_set_context_updates_existing_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.set_context(
      name: "prod",
      cluster: "development",
      user: "admin-dev",
      default_node: "pve2"
    )

    ctx = service.context("prod")
    assert_equal "development", ctx.cluster_ref
    assert_equal "admin-dev", ctx.user_ref
    assert_equal "pve2", ctx.default_node
  end

  def test_set_context_persists_to_file
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.set_context(
      name: "staging",
      cluster: "production",
      user: "admin-prod"
    )

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    staging = loaded["contexts"].find { |c| c["name"] == "staging" }
    assert staging
    assert_equal "production", staging["context"]["cluster"]
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end
end

# =============================================================================
# Config::Service Tests - Masked Config for Display
# =============================================================================

class ConfigServiceMaskedConfigTest < Minitest::Test
  # Test getting masked configuration for safe display

  def setup
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_masked_config_returns_hash
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    masked = service.masked_config

    assert_kind_of Hash, masked
  end

  def test_masked_config_masks_token_secret
    path = File.join(@fixtures_path, "token_auth_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    masked = service.masked_config

    user = masked["users"].first
    assert_equal "********", user["user"]["token-secret"]
  end

  def test_masked_config_masks_password
    path = File.join(@fixtures_path, "password_auth_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    masked = service.masked_config

    user = masked["users"].first
    assert_equal "********", user["user"]["password"]
  end

  def test_masked_config_preserves_non_secret_data
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    masked = service.masked_config

    assert_equal "pvectl/v1", masked["apiVersion"]
    assert_equal "Config", masked["kind"]
    assert_equal 2, masked["clusters"].size
    assert_equal "prod", masked["current-context"]
  end

  def test_masked_config_preserves_server_urls
    path = File.join(@fixtures_path, "valid_config.yml")
    service = Pvectl::Config::Service.new
    service.load(config: path)

    masked = service.masked_config

    cluster = masked["clusters"].first
    assert_equal "https://pve1.example.com:8006", cluster["cluster"]["server"]
  end
end

# =============================================================================
# Config::Service Tests - Save Method
# =============================================================================

class ConfigServiceSaveTest < Minitest::Test
  # Test saving configuration changes

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_save_writes_configuration
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.save

    assert File.exist?(path)
  end

  def test_save_preserves_secure_permissions
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    File.chmod(0o600, path)

    service = Pvectl::Config::Service.new
    service.load(config: path)
    service.save

    mode = File.stat(path).mode & 0o777
    assert_equal 0o600, mode
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end
end

# =============================================================================
# Config::Service Tests - Permission Warnings
# =============================================================================

class ConfigServicePermissionWarningsTest < Minitest::Test
  # Test insecure permission warnings

  def setup
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
      ENV.delete(var)
    end
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_load_warns_for_insecure_permissions
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    File.chmod(0o644, path) # world readable

    service = Pvectl::Config::Service.new
    warning = nil

    # Capture stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      service.load(config: path)
      warning = $stderr.string
    ensure
      $stderr = original_stderr
    end

    assert_match(/insecure|permission/i, warning)
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
  end
end
