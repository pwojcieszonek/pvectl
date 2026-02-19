# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Config::Provider Tests - File Loading
# =============================================================================

class ConfigProviderFileLoadingTest < Minitest::Test
  # Test loading configuration from YAML files

  def setup
    @provider = Pvectl::Config::Provider.new
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
  end

  def test_provider_class_exists
    assert_kind_of Class, Pvectl::Config::Provider
  end

  def test_file_exists_returns_true_for_existing_file
    path = File.join(@fixtures_path, "valid_config.yml")
    assert @provider.file_exists?(path)
  end

  def test_file_exists_returns_false_for_missing_file
    path = File.join(@fixtures_path, "nonexistent.yml")
    refute @provider.file_exists?(path)
  end

  def test_load_file_parses_valid_yaml
    path = File.join(@fixtures_path, "valid_config.yml")
    config = @provider.load_file(path)

    assert_kind_of Hash, config
    assert_equal "pvectl/v1", config["apiVersion"]
    assert_equal "Config", config["kind"]
  end

  def test_load_file_returns_clusters
    path = File.join(@fixtures_path, "valid_config.yml")
    config = @provider.load_file(path)

    assert config.key?("clusters")
    assert_kind_of Array, config["clusters"]
    assert_equal 2, config["clusters"].size
  end

  def test_load_file_returns_users
    path = File.join(@fixtures_path, "valid_config.yml")
    config = @provider.load_file(path)

    assert config.key?("users")
    assert_kind_of Array, config["users"]
    assert_equal 2, config["users"].size
  end

  def test_load_file_returns_contexts
    path = File.join(@fixtures_path, "valid_config.yml")
    config = @provider.load_file(path)

    assert config.key?("contexts")
    assert_kind_of Array, config["contexts"]
    assert_equal 2, config["contexts"].size
  end

  def test_load_file_returns_current_context
    path = File.join(@fixtures_path, "valid_config.yml")
    config = @provider.load_file(path)

    assert_equal "prod", config["current-context"]
  end

  def test_load_file_raises_for_missing_file
    path = File.join(@fixtures_path, "nonexistent.yml")

    assert_raises(Pvectl::Config::ConfigNotFoundError) do
      @provider.load_file(path)
    end
  end

  def test_load_file_raises_for_invalid_yaml
    path = File.join(@fixtures_path, "invalid_yaml.yml")

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_file(path)
    end
  end

  def test_load_file_with_token_auth
    path = File.join(@fixtures_path, "token_auth_config.yml")
    config = @provider.load_file(path)

    user = config["users"].first
    assert user["user"]["token-id"]
    assert user["user"]["token-secret"]
  end

  def test_load_file_with_password_auth
    path = File.join(@fixtures_path, "password_auth_config.yml")
    config = @provider.load_file(path)

    user = config["users"].first
    assert user["user"]["username"]
    assert user["user"]["password"]
  end
end

# =============================================================================
# Config::Provider Tests - Environment Variables
# =============================================================================

class ConfigProviderEnvLoadingTest < Minitest::Test
  # Test loading configuration from environment variables

  def setup
    @provider = Pvectl::Config::Provider.new
    # Store original env values
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
    end
  end

  def teardown
    # Restore original env values
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_env_vars_constant_is_defined
    assert_kind_of Hash, Pvectl::Config::Provider::ENV_VARS
  end

  def test_env_vars_includes_proxmox_host
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_HOST")
    assert_equal :server, Pvectl::Config::Provider::ENV_VARS["PROXMOX_HOST"]
  end

  def test_env_vars_includes_proxmox_token_id
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_TOKEN_ID")
    assert_equal :token_id, Pvectl::Config::Provider::ENV_VARS["PROXMOX_TOKEN_ID"]
  end

  def test_env_vars_includes_proxmox_token_secret
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_TOKEN_SECRET")
    assert_equal :token_secret, Pvectl::Config::Provider::ENV_VARS["PROXMOX_TOKEN_SECRET"]
  end

  def test_env_vars_includes_proxmox_user
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_USER")
    assert_equal :username, Pvectl::Config::Provider::ENV_VARS["PROXMOX_USER"]
  end

  def test_env_vars_includes_proxmox_password
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_PASSWORD")
    assert_equal :password, Pvectl::Config::Provider::ENV_VARS["PROXMOX_PASSWORD"]
  end

  def test_env_vars_includes_proxmox_verify_ssl
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_VERIFY_SSL")
    assert_equal :verify_ssl, Pvectl::Config::Provider::ENV_VARS["PROXMOX_VERIFY_SSL"]
  end

  def test_env_vars_includes_pvectl_context
    assert Pvectl::Config::Provider::ENV_VARS.key?("PVECTL_CONTEXT")
    assert_equal :context, Pvectl::Config::Provider::ENV_VARS["PVECTL_CONTEXT"]
  end

  def test_env_vars_includes_pvectl_config
    assert Pvectl::Config::Provider::ENV_VARS.key?("PVECTL_CONFIG")
    assert_equal :config_path, Pvectl::Config::Provider::ENV_VARS["PVECTL_CONFIG"]
  end

  def test_load_env_returns_empty_hash_when_no_vars_set
    # Clear all relevant env vars
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    result = @provider.load_env
    assert_kind_of Hash, result
    assert result.empty?
  end

  def test_load_env_returns_server_from_proxmox_host
    ENV["PROXMOX_HOST"] = "https://pve.example.com:8006"

    result = @provider.load_env
    assert_equal "https://pve.example.com:8006", result[:server]
  end

  def test_load_env_returns_token_credentials
    ENV["PROXMOX_TOKEN_ID"] = "root@pam!token"
    ENV["PROXMOX_TOKEN_SECRET"] = "secret-uuid"

    result = @provider.load_env
    assert_equal "root@pam!token", result[:token_id]
    assert_equal "secret-uuid", result[:token_secret]
  end

  def test_load_env_returns_password_credentials
    ENV["PROXMOX_USER"] = "root@pam"
    ENV["PROXMOX_PASSWORD"] = "secret"

    result = @provider.load_env
    assert_equal "root@pam", result[:username]
    assert_equal "secret", result[:password]
  end

  def test_load_env_parses_verify_ssl_true
    ENV["PROXMOX_VERIFY_SSL"] = "true"

    result = @provider.load_env
    assert_equal true, result[:verify_ssl]
  end

  def test_load_env_parses_verify_ssl_false
    ENV["PROXMOX_VERIFY_SSL"] = "false"

    result = @provider.load_env
    assert_equal false, result[:verify_ssl]
  end

  def test_load_env_parses_verify_ssl_1
    ENV["PROXMOX_VERIFY_SSL"] = "1"

    result = @provider.load_env
    assert_equal true, result[:verify_ssl]
  end

  def test_load_env_parses_verify_ssl_0
    ENV["PROXMOX_VERIFY_SSL"] = "0"

    result = @provider.load_env
    assert_equal false, result[:verify_ssl]
  end

  def test_load_env_returns_context
    ENV["PVECTL_CONTEXT"] = "production"

    result = @provider.load_env
    assert_equal "production", result[:context]
  end

  def test_load_env_returns_config_path
    ENV["PVECTL_CONFIG"] = "/custom/path/config"

    result = @provider.load_env
    assert_equal "/custom/path/config", result[:config_path]
  end
end

# =============================================================================
# Config::Provider Tests - Retry/Timeout Environment Variables (Feature 1.3)
# =============================================================================

class ConfigProviderRetryTimeoutEnvTest < Minitest::Test
  # Test loading retry/timeout settings from environment variables

  def setup
    @provider = Pvectl::Config::Provider.new
    # Store original env values
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
    end
  end

  def teardown
    # Restore original env values
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  # Test ENV_VARS constant includes new variables

  def test_env_vars_includes_proxmox_timeout
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_TIMEOUT")
    assert_equal :timeout, Pvectl::Config::Provider::ENV_VARS["PROXMOX_TIMEOUT"]
  end

  def test_env_vars_includes_proxmox_retry_count
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_RETRY_COUNT")
    assert_equal :retry_count, Pvectl::Config::Provider::ENV_VARS["PROXMOX_RETRY_COUNT"]
  end

  def test_env_vars_includes_proxmox_retry_delay
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_RETRY_DELAY")
    assert_equal :retry_delay, Pvectl::Config::Provider::ENV_VARS["PROXMOX_RETRY_DELAY"]
  end

  def test_env_vars_includes_proxmox_max_retry_delay
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_MAX_RETRY_DELAY")
    assert_equal :max_retry_delay, Pvectl::Config::Provider::ENV_VARS["PROXMOX_MAX_RETRY_DELAY"]
  end

  def test_env_vars_includes_proxmox_retry_writes
    assert Pvectl::Config::Provider::ENV_VARS.key?("PROXMOX_RETRY_WRITES")
    assert_equal :retry_writes, Pvectl::Config::Provider::ENV_VARS["PROXMOX_RETRY_WRITES"]
  end

  # Test INTEGER_VARS constant

  def test_integer_vars_constant_exists
    assert_kind_of Array, Pvectl::Config::Provider::INTEGER_VARS
  end

  def test_integer_vars_includes_timeout
    assert_includes Pvectl::Config::Provider::INTEGER_VARS, :timeout
  end

  def test_integer_vars_includes_retry_count
    assert_includes Pvectl::Config::Provider::INTEGER_VARS, :retry_count
  end

  def test_integer_vars_includes_retry_delay
    assert_includes Pvectl::Config::Provider::INTEGER_VARS, :retry_delay
  end

  def test_integer_vars_includes_max_retry_delay
    assert_includes Pvectl::Config::Provider::INTEGER_VARS, :max_retry_delay
  end

  # Test BOOLEAN_VARS constant

  def test_boolean_vars_constant_exists
    assert_kind_of Array, Pvectl::Config::Provider::BOOLEAN_VARS
  end

  def test_boolean_vars_includes_verify_ssl
    assert_includes Pvectl::Config::Provider::BOOLEAN_VARS, :verify_ssl
  end

  def test_boolean_vars_includes_retry_writes
    assert_includes Pvectl::Config::Provider::BOOLEAN_VARS, :retry_writes
  end

  # Test load_env parses new variables correctly

  def test_load_env_returns_timeout_as_integer
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_TIMEOUT"] = "60"

    result = @provider.load_env
    assert_equal 60, result[:timeout]
    assert_kind_of Integer, result[:timeout]
  end

  def test_load_env_returns_retry_count_as_integer
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_COUNT"] = "5"

    result = @provider.load_env
    assert_equal 5, result[:retry_count]
    assert_kind_of Integer, result[:retry_count]
  end

  def test_load_env_returns_retry_delay_as_integer
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_DELAY"] = "2"

    result = @provider.load_env
    assert_equal 2, result[:retry_delay]
    assert_kind_of Integer, result[:retry_delay]
  end

  def test_load_env_returns_max_retry_delay_as_integer
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_MAX_RETRY_DELAY"] = "60"

    result = @provider.load_env
    assert_equal 60, result[:max_retry_delay]
    assert_kind_of Integer, result[:max_retry_delay]
  end

  def test_load_env_parses_retry_writes_true
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_WRITES"] = "true"

    result = @provider.load_env
    assert_equal true, result[:retry_writes]
  end

  def test_load_env_parses_retry_writes_false
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_WRITES"] = "false"

    result = @provider.load_env
    assert_equal false, result[:retry_writes]
  end

  def test_load_env_parses_retry_writes_1
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_WRITES"] = "1"

    result = @provider.load_env
    assert_equal true, result[:retry_writes]
  end

  def test_load_env_parses_retry_writes_yes
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_WRITES"] = "yes"

    result = @provider.load_env
    assert_equal true, result[:retry_writes]
  end

  def test_load_env_accepts_zero_for_retry_count
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_COUNT"] = "0"

    result = @provider.load_env
    assert_equal 0, result[:retry_count]
  end

  # Test validation of non-numeric values

  def test_load_env_raises_for_non_numeric_timeout
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_TIMEOUT"] = "abc"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_load_env_raises_for_non_numeric_retry_count
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_COUNT"] = "five"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_load_env_raises_for_non_numeric_retry_delay
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_RETRY_DELAY"] = "two seconds"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_load_env_raises_for_non_numeric_max_retry_delay
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_MAX_RETRY_DELAY"] = "1min"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_load_env_raises_for_negative_timeout_string
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_TIMEOUT"] = "-5"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_load_env_raises_for_float_timeout
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_TIMEOUT"] = "30.5"

    assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end
  end

  def test_validation_error_message_includes_variable_name
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_TIMEOUT"] = "abc"

    error = assert_raises(Pvectl::Config::InvalidConfigError) do
      @provider.load_env
    end

    assert_includes error.message, "timeout"
    assert_includes error.message, "abc"
  end
end

# =============================================================================
# Config::Provider Tests - File Permissions
# =============================================================================

class ConfigProviderPermissionsTest < Minitest::Test
  # Test file permission checking

  def setup
    @provider = Pvectl::Config::Provider.new
    @temp_dir = Dir.mktmpdir("pvectl_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_insecure_permissions_returns_true_for_world_readable
    path = File.join(@temp_dir, "config")
    File.write(path, "test: data")
    File.chmod(0o644, path) # world readable

    assert @provider.insecure_permissions?(path)
  end

  def test_insecure_permissions_returns_true_for_group_readable
    path = File.join(@temp_dir, "config")
    File.write(path, "test: data")
    File.chmod(0o640, path) # group readable

    assert @provider.insecure_permissions?(path)
  end

  def test_insecure_permissions_returns_false_for_secure_file
    path = File.join(@temp_dir, "config")
    File.write(path, "test: data")
    File.chmod(0o600, path) # owner only

    refute @provider.insecure_permissions?(path)
  end

  def test_insecure_permissions_returns_false_for_nonexistent_file
    path = File.join(@temp_dir, "nonexistent")

    refute @provider.insecure_permissions?(path)
  end
end

# =============================================================================
# Config::Provider Tests - Context Resolution
# =============================================================================

class ConfigProviderContextResolutionTest < Minitest::Test
  # Test context name resolution from various sources

  def setup
    @provider = Pvectl::Config::Provider.new
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    @original_env = ENV["PVECTL_CONTEXT"]
  end

  def teardown
    if @original_env.nil?
      ENV.delete("PVECTL_CONTEXT")
    else
      ENV["PVECTL_CONTEXT"] = @original_env
    end
  end

  def test_resolve_context_name_from_cli_options
    ENV.delete("PVECTL_CONTEXT")

    result = @provider.resolve_context_name(
      cli_options: { context: "from-cli" },
      file_config: { "current-context" => "from-file" }
    )

    assert_equal "from-cli", result
  end

  def test_resolve_context_name_from_env
    ENV["PVECTL_CONTEXT"] = "from-env"

    result = @provider.resolve_context_name(
      cli_options: {},
      file_config: { "current-context" => "from-file" }
    )

    assert_equal "from-env", result
  end

  def test_resolve_context_name_from_file
    ENV.delete("PVECTL_CONTEXT")

    result = @provider.resolve_context_name(
      cli_options: {},
      file_config: { "current-context" => "from-file" }
    )

    assert_equal "from-file", result
  end

  def test_resolve_context_name_priority
    # CLI > ENV > file
    ENV["PVECTL_CONTEXT"] = "from-env"

    result = @provider.resolve_context_name(
      cli_options: { context: "from-cli" },
      file_config: { "current-context" => "from-file" }
    )

    assert_equal "from-cli", result
  end

  def test_resolve_context_name_returns_nil_when_not_set
    ENV.delete("PVECTL_CONTEXT")

    result = @provider.resolve_context_name(
      cli_options: {},
      file_config: {}
    )

    assert_nil result
  end
end

# =============================================================================
# Config::Provider Tests - Full Resolution
# =============================================================================

class ConfigProviderResolveTest < Minitest::Test
  # Test full configuration resolution with priority merging

  def setup
    @provider = Pvectl::Config::Provider.new
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
    # Store original env values
    @original_env = {}
    Pvectl::Config::Provider::ENV_VARS.keys.each do |var|
      @original_env[var] = ENV[var]
    end
  end

  def teardown
    # Restore original env values
    @original_env.each do |var, value|
      if value.nil?
        ENV.delete(var)
      else
        ENV[var] = value
      end
    end
  end

  def test_resolve_returns_resolved_config
    # Clear env vars
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(config_path: path, cli_options: {})

    assert_kind_of Pvectl::Config::Models::ResolvedConfig, result
  end

  def test_resolve_uses_current_context_from_file
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(config_path: path, cli_options: {})

    assert_equal "prod", result.context_name
    assert_equal "https://pve1.example.com:8006", result.server
  end

  def test_resolve_cli_options_override_file
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(
      config_path: path,
      cli_options: { context: "dev" }
    )

    assert_equal "dev", result.context_name
    assert_equal "https://pve-dev.local:8006", result.server
  end

  def test_resolve_env_overrides_file
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }
    ENV["PROXMOX_HOST"] = "https://env-override.example.com:8006"

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(config_path: path, cli_options: {})

    assert_equal "https://env-override.example.com:8006", result.server
  end

  def test_resolve_raises_for_missing_context
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "missing_context.yml")

    assert_raises(Pvectl::Config::ContextNotFoundError) do
      @provider.resolve(config_path: path, cli_options: {})
    end
  end

  def test_resolve_raises_for_missing_cluster_reference
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")

    assert_raises(Pvectl::Config::ClusterNotFoundError) do
      @provider.resolve(
        config_path: path,
        cli_options: { context: "prod" },
        # Simulate broken config by manipulating the provider
        # (test implementation detail - may need adjustment)
        cluster_override: "nonexistent"
      )
    end
  end

  def test_resolve_includes_verify_ssl
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(
      config_path: path,
      cli_options: { context: "dev" }
    )

    # dev context uses insecure-skip-tls-verify: true, so verify_ssl is false
    assert_equal false, result.verify_ssl
  end

  def test_resolve_includes_token_auth
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "token_auth_config.yml")
    result = @provider.resolve(config_path: path, cli_options: {})

    assert result.token_auth?
    assert_equal "root@pam!automation", result.token_id
  end

  def test_resolve_includes_password_auth
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "password_auth_config.yml")
    result = @provider.resolve(config_path: path, cli_options: {})

    assert result.password_auth?
    assert_equal "admin@pam", result.username
  end

  def test_resolve_includes_default_node
    Pvectl::Config::Provider::ENV_VARS.keys.each { |var| ENV.delete(var) }

    path = File.join(@fixtures_path, "valid_config.yml")
    result = @provider.resolve(
      config_path: path,
      cli_options: { context: "prod" }
    )

    assert_equal "pve1", result.default_node
  end
end
