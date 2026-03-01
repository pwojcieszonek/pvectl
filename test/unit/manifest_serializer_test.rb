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

  # ── from_yaml tests ─────────────────────────────────────────────

  def test_from_yaml_extracts_metadata_and_spec
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        name: web
        node: pve1
        status: running
      spec:
        hardware:
          cpu:
            cores: 4
          memory:
            memory: 8192
    YAML

    result = Pvectl::ManifestSerializer.from_yaml(yaml)

    assert_equal :vm, result[:type]
    assert_equal 100, result[:metadata][:vmid]
    assert_equal "web", result[:metadata][:name]
    assert_equal "pve1", result[:metadata][:node]
    assert_equal "running", result[:metadata][:status]
    assert_equal 4, result[:spec].dig(:hardware, :cpu, :cores)
    assert_equal 8192, result[:spec].dig(:hardware, :memory, :memory)
  end

  def test_from_yaml_container
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Container
      metadata:
        vmid: 200
        name: ct-web
        node: pve1
        status: running
      spec:
        resources:
          cpu:
            cores: 2
    YAML

    result = Pvectl::ManifestSerializer.from_yaml(yaml)

    assert_equal :container, result[:type]
    assert_equal 200, result[:metadata][:vmid]
  end

  # ── validate tests ──────────────────────────────────────────────

  def test_validate_accepts_valid_manifest
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        vmid: 100
        name: web
      spec:
        hardware:
          cpu:
            cores: 4
    YAML

    errors = Pvectl::ManifestSerializer.validate(yaml)

    assert_empty errors
  end

  def test_validate_rejects_missing_api_version
    yaml = <<~YAML
      kind: VirtualMachine
      metadata:
        vmid: 100
      spec: {}
    YAML

    errors = Pvectl::ManifestSerializer.validate(yaml)

    assert errors.any? { |e| e.include?("apiVersion") }
  end

  def test_validate_rejects_wrong_api_version
    yaml = <<~YAML
      apiVersion: pvectl/v2
      kind: VirtualMachine
      metadata:
        vmid: 100
      spec: {}
    YAML

    errors = Pvectl::ManifestSerializer.validate(yaml)

    assert errors.any? { |e| e.include?("Unsupported apiVersion") }
  end

  def test_validate_rejects_unknown_kind
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: Firewall
      metadata:
        vmid: 100
      spec: {}
    YAML

    errors = Pvectl::ManifestSerializer.validate(yaml)

    assert errors.any? { |e| e.include?("kind") }
  end

  def test_validate_accepts_missing_vmid
    yaml = <<~YAML
      apiVersion: pvectl/v1
      kind: VirtualMachine
      metadata:
        name: web
        node: pve1
      spec: {}
    YAML

    errors = Pvectl::ManifestSerializer.validate(yaml)

    assert_empty errors
  end
end
