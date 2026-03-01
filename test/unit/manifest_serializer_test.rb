# frozen_string_literal: true

require "test_helper"

class ManifestSerializerTest < Minitest::Test
  # ── to_yaml tests ──────────────────────────────────────────────

  def test_to_yaml_produces_valid_manifest
    nested_config = { hardware: { cpu: { cores: 4 } } }
    metadata = { vmid: 100, name: "web", node: "pve1", status: "running" }

    yaml = Pvectl::ManifestSerializer.to_yaml(nested_config, type: :vm, metadata: metadata)
    parsed = YAML.safe_load(yaml)

    assert_equal "pvectl/v1", parsed["apiVersion"]
    assert_equal "VirtualMachine", parsed["kind"]
    assert_equal 100, parsed.dig("metadata", "vmid")
    assert_equal "web", parsed.dig("metadata", "name")
    assert_equal "pve1", parsed.dig("metadata", "node")
    assert_equal "running", parsed.dig("metadata", "status")
    assert_equal 4, parsed.dig("spec", "hardware", "cpu", "cores")
  end

  def test_to_yaml_container
    nested_config = { resources: { cpu: { cores: 2 } } }
    metadata = { vmid: 200, name: "ct-web", node: "pve1", status: "running" }

    yaml = Pvectl::ManifestSerializer.to_yaml(nested_config, type: :container, metadata: metadata)
    parsed = YAML.safe_load(yaml)

    assert_equal "Container", parsed["kind"]
  end

  def test_to_yaml_includes_tags_in_metadata
    nested_config = { general: { name: "web" } }
    metadata = { vmid: 100, name: "web", node: "pve1", status: "running", tags: "prod;critical" }

    yaml = Pvectl::ManifestSerializer.to_yaml(nested_config, type: :vm, metadata: metadata)
    parsed = YAML.safe_load(yaml)

    assert_equal "prod;critical", parsed.dig("metadata", "tags")
  end
end
