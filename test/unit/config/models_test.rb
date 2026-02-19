# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Config::Models::Cluster Tests
# =============================================================================

class ConfigModelsClusterTest < Minitest::Test
  # Test the Cluster model which represents a Proxmox server configuration

  def test_cluster_class_exists
    assert_kind_of Class, Pvectl::Config::Models::Cluster
  end

  def test_cluster_has_name_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )
    assert_equal "production", cluster.name
  end

  def test_cluster_has_server_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )
    assert_equal "https://pve.example.com:8006", cluster.server
  end

  def test_cluster_has_verify_ssl_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      verify_ssl: false
    )
    assert_equal false, cluster.verify_ssl
  end

  def test_cluster_verify_ssl_defaults_to_true
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )
    assert_equal true, cluster.verify_ssl
  end

  def test_cluster_has_certificate_authority_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      certificate_authority: "/path/to/ca.crt"
    )
    assert_equal "/path/to/ca.crt", cluster.certificate_authority
  end

  def test_cluster_from_hash
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "certificate-authority" => "/path/to/ca.crt",
        "insecure-skip-tls-verify" => true
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal "production", cluster.name
    assert_equal "https://pve.example.com:8006", cluster.server
    assert_equal "/path/to/ca.crt", cluster.certificate_authority
    assert_equal false, cluster.verify_ssl # insecure-skip-tls-verify inverts
  end

  def test_cluster_to_hash
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      verify_ssl: false,
      certificate_authority: "/path/to/ca.crt"
    )
    hash = cluster.to_hash

    assert_equal "production", hash["name"]
    assert_equal "https://pve.example.com:8006", hash["cluster"]["server"]
    assert_equal true, hash["cluster"]["insecure-skip-tls-verify"]
    assert_equal "/path/to/ca.crt", hash["cluster"]["certificate-authority"]
  end

  def test_cluster_is_immutable
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )

    refute_respond_to cluster, :name=
    refute_respond_to cluster, :server=
  end
end

# =============================================================================
# Config::Models::Cluster Tests - Retry/Timeout Attributes (Feature 1.3)
# =============================================================================

class ConfigModelsClusterRetryTimeoutTest < Minitest::Test
  # Test retry and timeout configuration attributes

  def test_cluster_has_timeout_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      timeout: 60
    )
    assert_equal 60, cluster.timeout
  end

  def test_cluster_has_retry_count_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_count: 5
    )
    assert_equal 5, cluster.retry_count
  end

  def test_cluster_has_retry_delay_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_delay: 2
    )
    assert_equal 2, cluster.retry_delay
  end

  def test_cluster_has_max_retry_delay_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      max_retry_delay: 60
    )
    assert_equal 60, cluster.max_retry_delay
  end

  def test_cluster_has_retry_writes_attribute
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_writes: true
    )
    assert_equal true, cluster.retry_writes
  end

  def test_cluster_retry_timeout_attributes_default_to_nil
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )
    assert_nil cluster.timeout
    assert_nil cluster.retry_count
    assert_nil cluster.retry_delay
    assert_nil cluster.max_retry_delay
    assert_nil cluster.retry_writes
  end

  def test_cluster_from_hash_parses_timeout
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "timeout" => 60
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal 60, cluster.timeout
  end

  def test_cluster_from_hash_parses_retry_count
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "retry-count" => 5
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal 5, cluster.retry_count
  end

  def test_cluster_from_hash_parses_retry_delay
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "retry-delay" => 2
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal 2, cluster.retry_delay
  end

  def test_cluster_from_hash_parses_max_retry_delay
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "max-retry-delay" => 60
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal 60, cluster.max_retry_delay
  end

  def test_cluster_from_hash_parses_retry_writes
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "retry-writes" => true
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal true, cluster.retry_writes
  end

  def test_cluster_from_hash_parses_all_retry_timeout_settings
    hash = {
      "name" => "production",
      "cluster" => {
        "server" => "https://pve.example.com:8006",
        "timeout" => 45,
        "retry-count" => 4,
        "retry-delay" => 2,
        "max-retry-delay" => 30,
        "retry-writes" => true
      }
    }
    cluster = Pvectl::Config::Models::Cluster.from_hash(hash)

    assert_equal 45, cluster.timeout
    assert_equal 4, cluster.retry_count
    assert_equal 2, cluster.retry_delay
    assert_equal 30, cluster.max_retry_delay
    assert_equal true, cluster.retry_writes
  end

  def test_cluster_to_hash_includes_timeout_when_set
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      timeout: 60
    )
    hash = cluster.to_hash

    assert_equal 60, hash["cluster"]["timeout"]
  end

  def test_cluster_to_hash_includes_retry_settings_when_set
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_count: 5,
      retry_delay: 2,
      max_retry_delay: 30,
      retry_writes: true
    )
    hash = cluster.to_hash

    assert_equal 5, hash["cluster"]["retry-count"]
    assert_equal 2, hash["cluster"]["retry-delay"]
    assert_equal 30, hash["cluster"]["max-retry-delay"]
    assert_equal true, hash["cluster"]["retry-writes"]
  end

  def test_cluster_to_hash_omits_nil_retry_timeout_settings
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006"
    )
    hash = cluster.to_hash

    refute hash["cluster"].key?("timeout")
    refute hash["cluster"].key?("retry-count")
    refute hash["cluster"].key?("retry-delay")
    refute hash["cluster"].key?("max-retry-delay")
    # retry-writes should be present if not nil (even if false)
  end
end

# =============================================================================
# Config::Models::Cluster Tests - Validation (Feature 1.3)
# =============================================================================

class ConfigModelsClusterValidationTest < Minitest::Test
  # Test validation of retry/timeout settings

  def test_raises_for_negative_timeout
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        timeout: -5
      )
    end
  end

  def test_raises_for_zero_timeout
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        timeout: 0
      )
    end
  end

  def test_raises_for_negative_retry_count
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        retry_count: -1
      )
    end
  end

  def test_allows_zero_retry_count
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_count: 0
    )
    assert_equal 0, cluster.retry_count
  end

  def test_raises_for_negative_retry_delay
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        retry_delay: -1
      )
    end
  end

  def test_raises_for_zero_retry_delay
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        retry_delay: 0
      )
    end
  end

  def test_raises_for_negative_max_retry_delay
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        max_retry_delay: -1
      )
    end
  end

  def test_raises_when_max_retry_delay_less_than_retry_delay
    assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        retry_delay: 5,
        max_retry_delay: 2
      )
    end
  end

  def test_allows_max_retry_delay_equal_to_retry_delay
    cluster = Pvectl::Config::Models::Cluster.new(
      name: "production",
      server: "https://pve.example.com:8006",
      retry_delay: 5,
      max_retry_delay: 5
    )
    assert_equal 5, cluster.max_retry_delay
    assert_equal 5, cluster.retry_delay
  end

  def test_validation_error_includes_descriptive_message_for_timeout
    error = assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        timeout: -5
      )
    end

    assert_includes error.message, "timeout"
    assert_includes error.message, "positive"
  end

  def test_validation_error_includes_descriptive_message_for_max_retry_delay
    error = assert_raises(Pvectl::Config::InvalidConfigError) do
      Pvectl::Config::Models::Cluster.new(
        name: "production",
        server: "https://pve.example.com:8006",
        retry_delay: 10,
        max_retry_delay: 5
      )
    end

    assert_includes error.message, "max-retry-delay"
    assert_includes error.message, "retry-delay"
  end
end

# =============================================================================
# Config::Models::User Tests
# =============================================================================

class ConfigModelsUserTest < Minitest::Test
  # Test the User model which represents authentication credentials

  def test_user_class_exists
    assert_kind_of Class, Pvectl::Config::Models::User
  end

  def test_user_has_name_attribute
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal "admin", user.name
  end

  def test_user_with_token_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    )

    assert_equal "root@pam!token", user.token_id
    assert_equal "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", user.token_secret
    assert user.token_auth?
    refute user.password_auth?
  end

  def test_user_with_password_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      username: "root@pam",
      password: "secret"
    )

    assert_equal "root@pam", user.username
    assert_equal "secret", user.password
    assert user.password_auth?
    refute user.token_auth?
  end

  def test_user_valid_with_token_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert user.valid?
  end

  def test_user_valid_with_password_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      username: "root@pam",
      password: "secret"
    )
    assert user.valid?
  end

  def test_user_invalid_without_credentials
    user = Pvectl::Config::Models::User.new(name: "admin")
    refute user.valid?
  end

  def test_user_invalid_with_partial_token_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token"
      # missing token_secret
    )
    refute user.valid?
  end

  def test_user_invalid_with_partial_password_auth
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      username: "root@pam"
      # missing password
    )
    refute user.valid?
  end

  def test_user_from_hash_with_token
    hash = {
      "name" => "admin",
      "user" => {
        "token-id" => "root@pam!token",
        "token-secret" => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      }
    }
    user = Pvectl::Config::Models::User.from_hash(hash)

    assert_equal "admin", user.name
    assert_equal "root@pam!token", user.token_id
    assert_equal "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", user.token_secret
    assert user.token_auth?
  end

  def test_user_from_hash_with_password
    hash = {
      "name" => "admin",
      "user" => {
        "username" => "root@pam",
        "password" => "secret"
      }
    }
    user = Pvectl::Config::Models::User.from_hash(hash)

    assert_equal "admin", user.name
    assert_equal "root@pam", user.username
    assert_equal "secret", user.password
    assert user.password_auth?
  end

  def test_user_to_hash_without_masking
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    )
    hash = user.to_hash

    assert_equal "admin", hash["name"]
    assert_equal "root@pam!token", hash["user"]["token-id"]
    assert_equal "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", hash["user"]["token-secret"]
  end

  def test_user_to_hash_with_masking
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    )
    hash = user.to_hash(mask_secrets: true)

    assert_equal "admin", hash["name"]
    assert_equal "root@pam!token", hash["user"]["token-id"]
    assert_equal "********", hash["user"]["token-secret"]
  end

  def test_user_to_hash_masks_password
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      username: "root@pam",
      password: "mysecret"
    )
    hash = user.to_hash(mask_secrets: true)

    assert_equal "root@pam", hash["user"]["username"]
    assert_equal "********", hash["user"]["password"]
  end

  def test_user_is_immutable
    user = Pvectl::Config::Models::User.new(
      name: "admin",
      token_id: "root@pam!token",
      token_secret: "secret"
    )

    refute_respond_to user, :name=
    refute_respond_to user, :token_id=
    refute_respond_to user, :token_secret=
  end
end

# =============================================================================
# Config::Models::Context Tests
# =============================================================================

class ConfigModelsContextTest < Minitest::Test
  # Test the Context model which links clusters and users

  def test_context_class_exists
    assert_kind_of Class, Pvectl::Config::Models::Context
  end

  def test_context_has_name_attribute
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )
    assert_equal "prod", context.name
  end

  def test_context_has_cluster_ref_attribute
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )
    assert_equal "production", context.cluster_ref
  end

  def test_context_has_user_ref_attribute
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )
    assert_equal "admin", context.user_ref
  end

  def test_context_has_default_node_attribute
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin",
      default_node: "pve1"
    )
    assert_equal "pve1", context.default_node
  end

  def test_context_default_node_is_optional
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )
    assert_nil context.default_node
  end

  def test_context_from_hash
    hash = {
      "name" => "prod",
      "context" => {
        "cluster" => "production",
        "user" => "admin",
        "default-node" => "pve1"
      }
    }
    context = Pvectl::Config::Models::Context.from_hash(hash)

    assert_equal "prod", context.name
    assert_equal "production", context.cluster_ref
    assert_equal "admin", context.user_ref
    assert_equal "pve1", context.default_node
  end

  def test_context_to_hash
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin",
      default_node: "pve1"
    )
    hash = context.to_hash

    assert_equal "prod", hash["name"]
    assert_equal "production", hash["context"]["cluster"]
    assert_equal "admin", hash["context"]["user"]
    assert_equal "pve1", hash["context"]["default-node"]
  end

  def test_context_to_hash_omits_nil_default_node
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )
    hash = context.to_hash

    refute hash["context"].key?("default-node")
  end

  def test_context_is_immutable
    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "production",
      user_ref: "admin"
    )

    refute_respond_to context, :name=
    refute_respond_to context, :cluster_ref=
  end
end

# =============================================================================
# Config::Models::ResolvedConfig Tests
# =============================================================================

class ConfigModelsResolvedConfigTest < Minitest::Test
  # Test the ResolvedConfig model which is the final merged configuration

  def test_resolved_config_class_exists
    assert_kind_of Class, Pvectl::Config::Models::ResolvedConfig
  end

  def test_resolved_config_has_context_name
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal "prod", config.context_name
  end

  def test_resolved_config_has_server
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal "https://pve.example.com:8006", config.server
  end

  def test_resolved_config_has_verify_ssl
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      verify_ssl: false,
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal false, config.verify_ssl
  end

  def test_resolved_config_verify_ssl_defaults_to_true
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal true, config.verify_ssl
  end

  def test_resolved_config_with_token_auth
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )

    assert config.token_auth?
    refute config.password_auth?
    assert_equal "root@pam!token", config.token_id
    assert_equal "secret", config.token_secret
  end

  def test_resolved_config_with_password_auth
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :password,
      username: "root@pam",
      password: "secret"
    )

    assert config.password_auth?
    refute config.token_auth?
    assert_equal "root@pam", config.username
    assert_equal "secret", config.password
  end

  def test_resolved_config_has_default_node
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      default_node: "pve1"
    )
    assert_equal "pve1", config.default_node
  end

  def test_resolved_config_has_certificate_authority
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      certificate_authority: "/path/to/ca.crt"
    )
    assert_equal "/path/to/ca.crt", config.certificate_authority
  end

  def test_resolved_config_to_connection_options_for_token_auth
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      verify_ssl: false,
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    options = config.to_connection_options

    assert_equal "https://pve.example.com:8006", options[:server]
    assert_equal "root@pam!token", options[:token]
    assert_equal "secret", options[:secret]
    assert_equal false, options[:verify_ssl]
    refute options.key?(:username)
    refute options.key?(:password)
  end

  def test_resolved_config_to_connection_options_for_password_auth
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      verify_ssl: true,
      auth_type: :password,
      username: "root@pam",
      password: "secret"
    )
    options = config.to_connection_options

    assert_equal "https://pve.example.com:8006", options[:server]
    assert_equal "root@pam", options[:username]
    assert_equal "secret", options[:password]
    assert_equal true, options[:verify_ssl]
    refute options.key?(:token)
    refute options.key?(:secret)
  end

  def test_resolved_config_is_immutable
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )

    refute_respond_to config, :server=
    refute_respond_to config, :token_id=
  end
end

# =============================================================================
# Config::Models::ResolvedConfig Tests - Retry/Timeout Defaults (Feature 1.3)
# =============================================================================

class ConfigModelsResolvedConfigRetryTimeoutTest < Minitest::Test
  # Test retry/timeout attributes with default values

  def test_resolved_config_has_timeout_default_30
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal 30, config.timeout
  end

  def test_resolved_config_has_retry_count_default_3
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal 3, config.retry_count
  end

  def test_resolved_config_has_retry_delay_default_1
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal 1, config.retry_delay
  end

  def test_resolved_config_has_max_retry_delay_default_30
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal 30, config.max_retry_delay
  end

  def test_resolved_config_has_retry_writes_default_false
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret"
    )
    assert_equal false, config.retry_writes
  end

  def test_resolved_config_uses_provided_timeout_over_default
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      timeout: 60
    )
    assert_equal 60, config.timeout
  end

  def test_resolved_config_uses_provided_retry_count_over_default
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      retry_count: 5
    )
    assert_equal 5, config.retry_count
  end

  def test_resolved_config_uses_provided_retry_delay_over_default
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      retry_delay: 2
    )
    assert_equal 2, config.retry_delay
  end

  def test_resolved_config_uses_provided_max_retry_delay_over_default
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      max_retry_delay: 60
    )
    assert_equal 60, config.max_retry_delay
  end

  def test_resolved_config_uses_provided_retry_writes_over_default
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      retry_writes: true
    )
    assert_equal true, config.retry_writes
  end

  def test_resolved_config_allows_zero_retry_count
    config = Pvectl::Config::Models::ResolvedConfig.new(
      context_name: "prod",
      server: "https://pve.example.com:8006",
      auth_type: :token,
      token_id: "root@pam!token",
      token_secret: "secret",
      retry_count: 0
    )
    assert_equal 0, config.retry_count
  end

  def test_resolved_config_default_constants_are_defined
    assert_equal 30, Pvectl::Config::Models::ResolvedConfig::DEFAULT_TIMEOUT
    assert_equal 3, Pvectl::Config::Models::ResolvedConfig::DEFAULT_RETRY_COUNT
    assert_equal 1, Pvectl::Config::Models::ResolvedConfig::DEFAULT_RETRY_DELAY
    assert_equal 30, Pvectl::Config::Models::ResolvedConfig::DEFAULT_MAX_RETRY_DELAY
    assert_equal false, Pvectl::Config::Models::ResolvedConfig::DEFAULT_RETRY_WRITES
  end
end
