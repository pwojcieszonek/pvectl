# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# =============================================================================
# Config::Store Tests - Constants
# =============================================================================

class ConfigStoreConstantsTest < Minitest::Test
  # Test that security constants are properly defined

  def test_store_class_exists
    assert_kind_of Class, Pvectl::Config::Store
  end

  def test_secure_mode_constant
    assert_equal 0o600, Pvectl::Config::Store::SECURE_MODE
  end

  def test_secure_dir_mode_constant
    assert_equal 0o700, Pvectl::Config::Store::SECURE_DIR_MODE
  end
end

# =============================================================================
# Config::Store Tests - Saving Configuration
# =============================================================================

class ConfigStoreSaveTest < Minitest::Test
  # Test saving configuration to YAML files

  def setup
    @store = Pvectl::Config::Store.new
    @temp_dir = Dir.mktmpdir("pvectl_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_save_creates_file
    path = File.join(@temp_dir, "config")
    config = sample_config

    @store.save(path, config)

    assert File.exist?(path)
  end

  def test_save_creates_directory_if_missing
    path = File.join(@temp_dir, "subdir", "config")
    config = sample_config

    @store.save(path, config)

    assert File.exist?(path)
    assert File.directory?(File.dirname(path))
  end

  def test_save_sets_secure_file_permissions
    path = File.join(@temp_dir, "config")
    config = sample_config

    @store.save(path, config)

    mode = File.stat(path).mode & 0o777
    assert_equal 0o600, mode, "File should have 0600 permissions"
  end

  def test_save_sets_secure_directory_permissions
    path = File.join(@temp_dir, "newdir", "config")
    config = sample_config

    @store.save(path, config)

    dir_mode = File.stat(File.dirname(path)).mode & 0o777
    assert_equal 0o700, dir_mode, "Directory should have 0700 permissions"
  end

  def test_save_writes_valid_yaml
    path = File.join(@temp_dir, "config")
    config = sample_config

    @store.save(path, config)

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal "pvectl/v1", loaded["apiVersion"]
    assert_equal "Config", loaded["kind"]
  end

  def test_save_preserves_structure
    path = File.join(@temp_dir, "config")
    config = sample_config

    @store.save(path, config)

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert loaded.key?("clusters")
    assert loaded.key?("users")
    assert loaded.key?("contexts")
    assert loaded.key?("current-context")
  end

  def test_save_overwrites_existing_file
    path = File.join(@temp_dir, "config")

    # Write initial config
    File.write(path, "old: data")
    File.chmod(0o600, path)

    # Save new config
    @store.save(path, sample_config)

    content = File.read(path)
    refute_match(/old:/, content)
    assert_match(/apiVersion:/, content)
  end

  private

  def sample_config
    {
      "apiVersion" => "pvectl/v1",
      "kind" => "Config",
      "clusters" => [
        {
          "name" => "default",
          "cluster" => {
            "server" => "https://pve.example.com:8006"
          }
        }
      ],
      "users" => [
        {
          "name" => "default",
          "user" => {
            "token-id" => "root@pam!token",
            "token-secret" => "secret"
          }
        }
      ],
      "contexts" => [
        {
          "name" => "default",
          "context" => {
            "cluster" => "default",
            "user" => "default"
          }
        }
      ],
      "current-context" => "default"
    }
  end
end

# =============================================================================
# Config::Store Tests - Updating Current Context
# =============================================================================

class ConfigStoreUpdateCurrentContextTest < Minitest::Test
  # Test updating just the current-context field

  def setup
    @store = Pvectl::Config::Store.new
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_update_current_context_changes_value
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    @store.update_current_context(path, "dev")

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal "dev", loaded["current-context"]
  end

  def test_update_current_context_preserves_other_data
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    @store.update_current_context(path, "dev")

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal 2, loaded["clusters"].size
    assert_equal 2, loaded["users"].size
    assert_equal 2, loaded["contexts"].size
  end

  def test_update_current_context_preserves_permissions
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    File.chmod(0o600, path)

    @store.update_current_context(path, "dev")

    mode = File.stat(path).mode & 0o777
    assert_equal 0o600, mode
  end

  def test_update_current_context_raises_for_missing_file
    path = File.join(@temp_dir, "nonexistent")

    assert_raises(Pvectl::Config::ConfigNotFoundError) do
      @store.update_current_context(path, "dev")
    end
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end
end

# =============================================================================
# Config::Store Tests - Upserting Context
# =============================================================================

class ConfigStoreUpsertContextTest < Minitest::Test
  # Test creating or updating a context

  def setup
    @store = Pvectl::Config::Store.new
    @temp_dir = Dir.mktmpdir("pvectl_test")
    @fixtures_path = File.expand_path("../../fixtures/config", __dir__)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_upsert_context_adds_new_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    context = Pvectl::Config::Models::Context.new(
      name: "staging",
      cluster_ref: "production",
      user_ref: "admin-prod"
    )

    @store.upsert_context(path, context)

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    assert_equal 3, loaded["contexts"].size

    new_context = loaded["contexts"].find { |c| c["name"] == "staging" }
    assert_equal "production", new_context["context"]["cluster"]
    assert_equal "admin-prod", new_context["context"]["user"]
  end

  def test_upsert_context_updates_existing_context
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    context = Pvectl::Config::Models::Context.new(
      name: "prod",
      cluster_ref: "development",
      user_ref: "admin-dev",
      default_node: "pve2"
    )

    @store.upsert_context(path, context)

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    # Should still have 2 contexts, not 3
    assert_equal 2, loaded["contexts"].size

    updated_context = loaded["contexts"].find { |c| c["name"] == "prod" }
    assert_equal "development", updated_context["context"]["cluster"]
    assert_equal "admin-dev", updated_context["context"]["user"]
    assert_equal "pve2", updated_context["context"]["default-node"]
  end

  def test_upsert_context_preserves_other_contexts
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)

    context = Pvectl::Config::Models::Context.new(
      name: "staging",
      cluster_ref: "production",
      user_ref: "admin-prod"
    )

    @store.upsert_context(path, context)

    loaded = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
    prod_context = loaded["contexts"].find { |c| c["name"] == "prod" }
    dev_context = loaded["contexts"].find { |c| c["name"] == "dev" }

    assert prod_context, "prod context should still exist"
    assert dev_context, "dev context should still exist"
  end

  def test_upsert_context_preserves_permissions
    path = File.join(@temp_dir, "config")
    copy_fixture("valid_config.yml", path)
    File.chmod(0o600, path)

    context = Pvectl::Config::Models::Context.new(
      name: "staging",
      cluster_ref: "production",
      user_ref: "admin-prod"
    )

    @store.upsert_context(path, context)

    mode = File.stat(path).mode & 0o777
    assert_equal 0o600, mode
  end

  def test_upsert_context_raises_for_missing_file
    path = File.join(@temp_dir, "nonexistent")

    context = Pvectl::Config::Models::Context.new(
      name: "staging",
      cluster_ref: "production",
      user_ref: "admin-prod"
    )

    assert_raises(Pvectl::Config::ConfigNotFoundError) do
      @store.upsert_context(path, context)
    end
  end

  private

  def copy_fixture(fixture_name, dest_path)
    src = File.join(@fixtures_path, fixture_name)
    FileUtils.cp(src, dest_path)
    File.chmod(0o600, dest_path)
  end
end

# =============================================================================
# Config::Store Tests - Error Handling
# =============================================================================

class ConfigStoreErrorHandlingTest < Minitest::Test
  # Test error handling for file operations

  def setup
    @store = Pvectl::Config::Store.new
    @temp_dir = Dir.mktmpdir("pvectl_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_save_raises_for_permission_denied
    # Create a directory without write permissions
    readonly_dir = File.join(@temp_dir, "readonly")
    FileUtils.mkdir_p(readonly_dir)
    File.chmod(0o500, readonly_dir)

    path = File.join(readonly_dir, "config")
    config = { "test" => "data" }

    assert_raises(Errno::EACCES) do
      @store.save(path, config)
    end
  ensure
    # Restore permissions for cleanup
    File.chmod(0o700, readonly_dir) if File.exist?(readonly_dir)
  end
end
