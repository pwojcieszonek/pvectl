# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Apt Tests
# =============================================================================

class RepositoriesAptTest < Minitest::Test
  def setup
    @pending_response = [
      {
        Package: "pve-manager",
        Title: "Proxmox VE Manager",
        Version: "8.2.4-1",
        OldVersion: "8.2.3-1",
        Origin: "Proxmox",
        Section: "admin",
        Priority: "optional",
        Arch: "amd64",
        Description: "Proxmox VE management server"
      },
      {
        Package: "libc6",
        Title: "GNU C Library",
        Version: "2.36-9+deb12u7",
        OldVersion: "2.36-9+deb12u6",
        Origin: "Debian",
        Section: "libs",
        Priority: "required",
        Arch: "amd64",
        Description: "GNU C Library: Shared libraries"
      }
    ]

    @versions_response = [
      {
        Package: "proxmox-ve",
        Version: "8.2.0",
        OldVersion: "8.2.0",
        CurrentState: "Installed",
        ManagerVersion: "pve-manager/8.2.4-1/abc",
        RunningKernel: "6.8.4-2-pve",
        Origin: "Proxmox",
        Arch: "amd64"
      }
    ]

    @changelog_text = <<~LOG
      pve-manager (8.2.4-1) bookworm; urgency=medium

        * Bump version to 8.2.4-1
        * Fix VM cloning regression

       -- Proxmox Support Team <support@proxmox.com>
    LOG
  end

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_class_exists
    assert_kind_of Class, Pvectl::Repositories::Apt
  end

  def test_inherits_from_base
    assert Pvectl::Repositories::Apt < Pvectl::Repositories::Base
  end

  # ---------------------------
  # #pending
  # ---------------------------

  def test_pending_returns_apt_package_models
    repo = build_repo(pending: { "pve1" => @pending_response })

    packages = repo.pending("pve1")

    assert_equal 2, packages.size
    assert packages.all? { |p| p.is_a?(Pvectl::Models::AptPackage) }
  end

  def test_pending_maps_fields_correctly
    repo = build_repo(pending: { "pve1" => @pending_response })

    pkg = repo.pending("pve1").first

    assert_equal "pve-manager", pkg.package
    assert_equal "8.2.4-1", pkg.version
    assert_equal "8.2.3-1", pkg.old_version
    assert_equal "Proxmox", pkg.origin
    assert_equal "amd64", pkg.arch
  end

  def test_pending_sets_node_on_models
    repo = build_repo(pending: { "pve1" => @pending_response })

    packages = repo.pending("pve1")

    assert packages.all? { |p| p.node == "pve1" }
  end

  def test_pending_returns_empty_on_api_error
    repo = build_repo(pending: { "pve1" => StandardError.new("API down") })

    assert_empty repo.pending("pve1")
  end

  def test_pending_returns_empty_when_no_updates
    repo = build_repo(pending: { "pve1" => [] })

    assert_empty repo.pending("pve1")
  end

  # ---------------------------
  # #refresh
  # ---------------------------

  def test_refresh_returns_upid
    repo = build_repo

    upid = repo.refresh("pve1")

    assert_equal "UPID:pve1:apt-update", upid
  end

  def test_refresh_records_post_invocation
    repo = build_repo

    repo.refresh("pve1", notify: true, quiet: true)

    last_post = mock_connection.client.last_post
    assert_equal "nodes/pve1/apt/update", last_post[:path]
    assert_equal 1, last_post[:payload][:notify]
    assert_equal 1, last_post[:payload][:quiet]
  end

  def test_refresh_defaults_omit_notify_and_quiet
    repo = build_repo

    repo.refresh("pve1")

    payload = mock_connection.client.last_post[:payload]
    refute payload.key?(:notify)
    refute payload.key?(:quiet)
  end

  # ---------------------------
  # #changelog
  # ---------------------------

  def test_changelog_returns_text_string
    repo = build_repo(changelogs: { ["pve1", "pve-manager"] => @changelog_text })

    text = repo.changelog("pve1", "pve-manager")

    assert_equal @changelog_text, text
  end

  def test_changelog_passes_version_param
    repo = build_repo(changelogs: { ["pve1", "pve-manager"] => @changelog_text })

    repo.changelog("pve1", "pve-manager", version: "8.2.4-1")

    last_get = mock_connection.client.last_get
    assert_equal "nodes/pve1/apt/changelog", last_get[:path]
    assert_equal "pve-manager", last_get[:params][:name]
    assert_equal "8.2.4-1", last_get[:params][:version]
  end

  def test_changelog_omits_version_when_nil
    repo = build_repo(changelogs: { ["pve1", "pve-manager"] => @changelog_text })

    repo.changelog("pve1", "pve-manager")

    last_get = mock_connection.client.last_get
    refute last_get[:params].key?(:version)
  end

  def test_changelog_returns_empty_string_on_error
    repo = build_repo(changelogs: { ["pve1", "missing"] => StandardError.new("not found") })

    assert_equal "", repo.changelog("pve1", "missing")
  end

  # ---------------------------
  # #versions
  # ---------------------------

  def test_versions_returns_apt_package_models
    repo = build_repo(versions: { "pve1" => @versions_response })

    packages = repo.versions("pve1")

    assert_equal 1, packages.size
    assert packages.all? { |p| p.is_a?(Pvectl::Models::AptPackage) }
  end

  def test_versions_maps_version_specific_fields
    repo = build_repo(versions: { "pve1" => @versions_response })

    pkg = repo.versions("pve1").first

    assert_equal "proxmox-ve", pkg.package
    assert_equal "Installed", pkg.current_state
    assert_equal "pve-manager/8.2.4-1/abc", pkg.manager_version
    assert_equal "6.8.4-2-pve", pkg.running_kernel
    assert_equal "pve1", pkg.node
  end

  def test_versions_returns_empty_on_api_error
    repo = build_repo(versions: { "pve1" => StandardError.new("nope") })

    assert_empty repo.versions("pve1")
  end

  private

  attr_reader :mock_connection

  def build_repo(pending: {}, versions: {}, changelogs: {})
    @mock_connection = MockAptConnection.new(pending: pending, versions: versions, changelogs: changelogs)
    Pvectl::Repositories::Apt.new(@mock_connection)
  end

  class MockAptConnection
    def initialize(pending:, versions:, changelogs:)
      @client = MockClient.new(pending: pending, versions: versions, changelogs: changelogs)
    end

    attr_reader :client
  end

  class MockClient
    attr_reader :last_get, :last_post

    def initialize(pending:, versions:, changelogs:)
      @pending = pending
      @versions = versions
      @changelogs = changelogs
      @last_get = nil
      @last_post = nil
    end

    def [](path)
      MockEndpoint.new(path, self)
    end

    def record_get(path, params)
      @last_get = { path: path, params: params }
    end

    def record_post(path, payload)
      @last_post = { path: path, payload: payload }
    end

    attr_reader :pending, :versions, :changelogs
  end

  class MockEndpoint
    def initialize(path, client)
      @path = path
      @client = client
    end

    def get(**kwargs)
      params = kwargs[:params] || {}
      @client.record_get(@path, params)

      case @path
      when %r{\Anodes/([^/]+)/apt/update\z}
        node = Regexp.last_match(1)
        result = @client.pending[node]
        raise result if result.is_a?(StandardError)

        result || []
      when %r{\Anodes/([^/]+)/apt/versions\z}
        node = Regexp.last_match(1)
        result = @client.versions[node]
        raise result if result.is_a?(StandardError)

        result || []
      when %r{\Anodes/([^/]+)/apt/changelog\z}
        node = Regexp.last_match(1)
        package = params[:name]
        result = @client.changelogs[[node, package]]
        raise result if result.is_a?(StandardError)

        result || ""
      else
        nil
      end
    end

    def post(payload = {})
      @client.record_post(@path, payload || {})
      case @path
      when %r{\Anodes/([^/]+)/apt/update\z}
        node = Regexp.last_match(1)
        "UPID:#{node}:apt-update"
      else
        ""
      end
    end
  end
end
