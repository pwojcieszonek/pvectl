# frozen_string_literal: true

require "test_helper"

class ConfigSerializerTest < Minitest::Test
  # ── to_yaml tests ──────────────────────────────────────────────

  def test_to_yaml_groups_vm_config_into_sections
    config = { vmid: 100, name: "web", cores: 4, memory: 8192, net0: "virtio=AA:BB,bridge=vmbr0" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert_equal 100, parsed.dig("general", "vmid")
    assert_equal "web", parsed.dig("general", "name")
    assert_equal 4, parsed.dig("cpu", "cores")
    assert_equal 8192, parsed.dig("memory", "memory")
    assert_equal "virtio=AA:BB,bridge=vmbr0", parsed.dig("network", "net0")
  end

  def test_to_yaml_includes_header_comment
    config = { vmid: 100, name: "web" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    assert_includes yaml, "# Editing VM 100 on node pve1 (status: running)"
    assert_includes yaml, "# Fields marked"
    assert_includes yaml, "# Save and close"
  end

  def test_to_yaml_marks_readonly_fields
    config = { vmid: 100, name: "web", digest: "abc123" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    assert_match(/vmid: 100\s+# read-only/, yaml)
    assert_match(/digest: ["']?abc123["']?\s+# read-only/, yaml)
    refute_match(/name: ["']?web["']?\s+# read-only/, yaml)
  end

  def test_to_yaml_omits_keys_not_in_section_mapping
    config = { vmid: 100, name: "web", some_unknown_key: "value" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    refute_includes yaml, "some_unknown_key"
  end

  def test_to_yaml_handles_dynamic_keys
    config = { vmid: 100, scsi0: "local-lvm:vm-100-disk-0,size=32G", scsi1: "local-lvm:vm-100-disk-1,size=64G",
               net0: "virtio=AA:BB,bridge=vmbr0", net1: "virtio=CC:DD,bridge=vmbr1" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert parsed.dig("disks", "scsi0")
    assert parsed.dig("disks", "scsi1")
    assert parsed.dig("network", "net0")
    assert parsed.dig("network", "net1")
  end

  def test_to_yaml_omits_empty_sections
    config = { vmid: 100, cores: 4 }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert parsed.key?("general")
    assert parsed.key?("cpu")
    refute parsed.key?("memory")
    refute parsed.key?("network")
    refute parsed.key?("disks")
  end

  def test_to_yaml_groups_container_config_into_sections
    config = { vmid: 200, hostname: "ct-web", cores: 2, memory: 512, swap: 256,
               rootfs: "local-lvm:vm-200-disk-0,size=8G", net0: "name=eth0,bridge=vmbr0" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :container,
                                            resource: { vmid: 200, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert_equal 200, parsed.dig("general", "vmid")
    assert_equal "ct-web", parsed.dig("general", "hostname")
    assert_equal 2, parsed.dig("cpu", "cores")
    assert_equal 512, parsed.dig("memory", "memory")
    assert_equal 256, parsed.dig("memory", "swap")
    assert parsed.dig("disks", "rootfs")
    assert parsed.dig("network", "net0")
  end

  def test_to_yaml_marks_container_readonly_fields
    config = { vmid: 200, hostname: "ct-web", arch: "amd64" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :container,
                                            resource: { vmid: 200, node: "pve1", status: "running" })

    assert_match(/vmid: 200\s+# read-only/, yaml)
    assert_match(/arch: ["']?amd64["']?\s+# read-only/, yaml)
    refute_match(/hostname: ["']?ct-web["']?\s+# read-only/, yaml)
  end

  # ── from_yaml tests ────────────────────────────────────────────

  def test_from_yaml_flattens_nested_structure
    yaml = <<~YAML
      general:
        vmid: 100
        name: web
      cpu:
        cores: 4
      memory:
        memory: 8192
    YAML

    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :vm)

    assert_equal 100, result[:vmid]
    assert_equal "web", result[:name]
    assert_equal 4, result[:cores]
    assert_equal 8192, result[:memory]
  end

  def test_from_yaml_strips_comments
    yaml = <<~YAML
      # This is a header comment
      # Another comment
      general:
        vmid: 100  # read-only
        name: web
    YAML

    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :vm)

    assert_equal 100, result[:vmid]
    assert_equal "web", result[:name]
  end

  def test_from_yaml_returns_empty_hash_for_empty_string
    result = Pvectl::ConfigSerializer.from_yaml("", type: :vm)

    assert_equal({}, result)
  end

  # ── validate tests ─────────────────────────────────────────────

  def test_validate_returns_empty_for_valid_yaml
    yaml = <<~YAML
      general:
        name: web
      cpu:
        cores: 4
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert_empty errors
  end

  def test_validate_catches_unknown_section
    yaml = <<~YAML
      general:
        name: web
      foo:
        bar: 1
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert_includes errors, "Unknown section 'foo'"
  end

  def test_validate_catches_unknown_key
    yaml = <<~YAML
      cpu:
        turbo: true
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("Unknown key 'turbo'") && e.include?("cpu") }
  end

  def test_validate_catches_syntax_error
    yaml = "general:\n  name: [invalid yaml"

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("YAML syntax error") }
  end

  def test_validate_accepts_dynamic_keys
    yaml = <<~YAML
      disks:
        scsi0: "local-lvm:vm-100-disk-0,size=32G"
        scsi1: "local-lvm:vm-100-disk-1,size=64G"
      network:
        net0: "virtio=AA:BB,bridge=vmbr0"
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert_empty errors
  end

  # ── readonly_violations tests ──────────────────────────────────

  def test_readonly_violations_detects_vmid_change
    original = { vmid: 100, name: "web", cores: 4 }
    edited = { vmid: 999, name: "web", cores: 4 }

    violations = Pvectl::ConfigSerializer.readonly_violations(original, edited, type: :vm)

    assert_includes violations, "vmid"
  end

  def test_readonly_violations_detects_digest_change
    original = { vmid: 100, digest: "abc123", cores: 4 }
    edited = { vmid: 100, digest: "changed", cores: 4 }

    violations = Pvectl::ConfigSerializer.readonly_violations(original, edited, type: :vm)

    assert_includes violations, "digest"
  end

  def test_readonly_violations_ignores_non_readonly_changes
    original = { vmid: 100, name: "web", cores: 4 }
    edited = { vmid: 100, name: "api", cores: 8 }

    violations = Pvectl::ConfigSerializer.readonly_violations(original, edited, type: :vm)

    assert_empty violations
  end

  def test_readonly_violations_detects_arch_change_for_container
    original = { vmid: 200, hostname: "ct", arch: "amd64" }
    edited = { vmid: 200, hostname: "ct", arch: "arm64" }

    violations = Pvectl::ConfigSerializer.readonly_violations(original, edited, type: :container)

    assert_includes violations, "arch"
  end

  # ── diff tests ─────────────────────────────────────────────────

  def test_diff_detects_changed_value
    original = { cores: 4, memory: 8192 }
    edited = { cores: 8, memory: 8192 }

    result = Pvectl::ConfigSerializer.diff(original, edited)

    assert_equal({ cores: [4, 8] }, result[:changed])
  end

  def test_diff_detects_added_key
    original = { cores: 4 }
    edited = { cores: 4, balloon: 2048 }

    result = Pvectl::ConfigSerializer.diff(original, edited)

    assert_equal({ balloon: 2048 }, result[:added])
  end

  def test_diff_detects_removed_key
    original = { cores: 4, description: "old" }
    edited = { cores: 4 }

    result = Pvectl::ConfigSerializer.diff(original, edited)

    assert_includes result[:removed], :description
  end

  def test_diff_returns_empty_when_no_changes
    config = { cores: 4, memory: 8192 }

    result = Pvectl::ConfigSerializer.diff(config, config.dup)

    assert_empty result[:changed]
    assert_empty result[:added]
    assert_empty result[:removed]
  end

  # ── format_diff tests ──────────────────────────────────────────

  def test_format_diff_shows_colored_output
    diff = {
      changed: { cores: [4, 8] },
      added: { balloon: 2048 },
      removed: [:description]
    }

    output = Pvectl::ConfigSerializer.format_diff(diff)

    # Verify content (stripping ANSI codes for assertion)
    stripped = output.gsub(/\e\[[0-9;]*m/, "")
    assert_includes stripped, "~ cores: 4 -> 8"
    assert_includes stripped, "+ balloon: 2048"
    assert_includes stripped, "- description"
  end

  private

  # Strips comment lines from YAML string for safe parsing.
  #
  # @param yaml [String] YAML string with comments
  # @return [String] YAML string without comment lines
  def yaml_without_comments(yaml)
    yaml.lines.reject { |line| line.strip.start_with?("#") || line.strip.empty? }.join
  end
end
