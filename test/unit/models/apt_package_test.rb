# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Models::AptPackage Tests
# =============================================================================

class ModelsAptPackageTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Models::AptPackage
  end

  def test_inherits_from_base
    assert Pvectl::Models::AptPackage < Pvectl::Models::Base
  end

  def test_accepts_proxmox_capitalized_keys
    pkg = Pvectl::Models::AptPackage.new(
      Package: "pve-manager",
      Title: "Proxmox VE Manager",
      Version: "8.2.4-1",
      OldVersion: "8.2.3-1",
      Origin: "Proxmox",
      Section: "admin",
      Priority: "optional",
      Arch: "amd64",
      Description: "Proxmox VE management server",
      node: "pve1"
    )

    assert_equal "pve-manager", pkg.package
    assert_equal "Proxmox VE Manager", pkg.title
    assert_equal "8.2.4-1", pkg.version
    assert_equal "8.2.3-1", pkg.old_version
    assert_equal "Proxmox", pkg.origin
    assert_equal "admin", pkg.section
    assert_equal "optional", pkg.priority
    assert_equal "amd64", pkg.arch
    assert_equal "Proxmox VE management server", pkg.description
    assert_equal "pve1", pkg.node
  end

  def test_accepts_snake_case_keys
    pkg = Pvectl::Models::AptPackage.new(
      package: "pve-manager",
      version: "8.2.4-1",
      old_version: "8.2.3-1",
      origin: "Proxmox"
    )

    assert_equal "pve-manager", pkg.package
    assert_equal "8.2.4-1", pkg.version
    assert_equal "8.2.3-1", pkg.old_version
    assert_equal "Proxmox", pkg.origin
  end

  def test_accepts_dasherized_keys
    pkg = Pvectl::Models::AptPackage.new(
      :Package => "pve-kernel",
      :"old-version" => "6.5.13-1-pve",
      :"notify-status" => "6.8.4-2-pve",
      :"current-state" => "Installed"
    )

    assert_equal "pve-kernel", pkg.package
    assert_equal "6.5.13-1-pve", pkg.old_version
    assert_equal "6.8.4-2-pve", pkg.notify_status
    assert_equal "Installed", pkg.current_state
  end

  def test_versions_fields_populated
    pkg = Pvectl::Models::AptPackage.new(
      Package: "proxmox-ve",
      Version: "8.2.0",
      CurrentState: "Installed",
      ManagerVersion: "pve-manager/8.2.4/abc",
      RunningKernel: "6.8.4-2-pve"
    )

    assert_equal "Installed", pkg.current_state
    assert_equal "pve-manager/8.2.4/abc", pkg.manager_version
    assert_equal "6.8.4-2-pve", pkg.running_kernel
  end

  def test_upgrade_predicate_when_versions_differ
    pkg = Pvectl::Models::AptPackage.new(Package: "pve-manager", Version: "8.2.4-1", OldVersion: "8.2.3-1")
    assert pkg.upgrade?
  end

  def test_upgrade_predicate_false_when_no_old_version
    pkg = Pvectl::Models::AptPackage.new(Package: "pve-manager", Version: "8.2.4-1")
    refute pkg.upgrade?
  end

  def test_upgrade_predicate_false_when_versions_equal
    pkg = Pvectl::Models::AptPackage.new(Package: "pve-manager", Version: "8.2.4-1", OldVersion: "8.2.4-1")
    refute pkg.upgrade?
  end

  def test_installed_state_defaults_to_installed_when_missing
    pkg = Pvectl::Models::AptPackage.new(Package: "pve-manager")
    assert_equal "Installed", pkg.installed_state
  end

  def test_installed_state_uses_current_state_when_present
    pkg = Pvectl::Models::AptPackage.new(Package: "pve-manager", CurrentState: "HalfInstalled")
    assert_equal "HalfInstalled", pkg.installed_state
  end

  def test_attributes_default_to_nil
    pkg = Pvectl::Models::AptPackage.new

    assert_nil pkg.package
    assert_nil pkg.version
    assert_nil pkg.origin
    assert_nil pkg.node
  end
end
