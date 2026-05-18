# frozen_string_literal: true

require "test_helper"

class ModelsCapabilityTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Models::Capability
  end

  def test_inherits_from_base
    assert Pvectl::Models::Capability < Pvectl::Models::Base
  end

  def test_cpu_attributes
    cap = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :cpu, name: "host", vendor: "GenuineIntel"
    )

    assert_equal "pve1", cap.node_name
    assert_equal :cpu, cap.kind
    assert_equal "host", cap.name
    assert_equal "GenuineIntel", cap.vendor
    assert_equal false, cap.custom
  end

  def test_custom_cpu_flag
    cap = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :cpu, name: "custom-mycpu", custom: true
    )

    assert_equal true, cap.custom
  end

  def test_machine_attributes
    cap = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :machine, name: "pc-q35-8.1",
      machine_type: "q35", version: "8.1", changes: "fixed bug"
    )

    assert_equal :machine, cap.kind
    assert_equal "pc-q35-8.1", cap.name
    assert_equal "q35", cap.machine_type
    assert_equal "8.1", cap.version
    assert_equal "fixed bug", cap.changes
  end

  def test_defaults_when_attributes_missing
    cap = Pvectl::Models::Capability.new

    assert_nil cap.node_name
    assert_nil cap.kind
    assert_nil cap.name
    assert_equal false, cap.custom
  end
end
