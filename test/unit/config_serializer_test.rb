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
    assert_equal 4, parsed.dig("hardware", "cpu", "cores")
    assert_equal 8192, parsed.dig("hardware", "memory", "memory")
    assert_equal "virtio=AA:BB,bridge=vmbr0", parsed.dig("hardware", "network", "net0")
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

    assert parsed.dig("hardware", "disks", "scsi0")
    assert parsed.dig("hardware", "disks", "scsi1")
    assert parsed.dig("hardware", "network", "net0")
    assert parsed.dig("hardware", "network", "net1")
  end

  def test_to_yaml_omits_empty_sections
    config = { vmid: 100, cores: 4 }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert parsed.key?("general")
    assert parsed.key?("hardware")
    assert parsed.dig("hardware", "cpu")
    refute parsed.dig("hardware", "memory")
    refute parsed.dig("hardware", "network")
    refute parsed.dig("hardware", "disks")
  end

  def test_to_yaml_groups_container_config_into_sections
    config = { vmid: 200, hostname: "ct-web", cores: 2, memory: 512, swap: 256,
               rootfs: "local-lvm:vm-200-disk-0,size=8G", net0: "name=eth0,bridge=vmbr0" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :container,
                                            resource: { vmid: 200, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert_equal 200, parsed.dig("general", "vmid")
    assert_equal "ct-web", parsed.dig("general", "hostname")
    assert_equal 2, parsed.dig("resources", "cpu", "cores")
    assert_equal 512, parsed.dig("resources", "memory", "memory")
    assert_equal 256, parsed.dig("resources", "memory", "swap")
    assert parsed.dig("resources", "disks", "rootfs")
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

  # ── to_yaml wrapper section tests ───────────────────────────────

  def test_to_yaml_wrapper_section_renders_three_level_nesting
    config = { vmid: 100, cores: 4, memory: 8192, net0: "virtio=AA:BB,bridge=vmbr0" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    # Verify 3-level indentation structure
    assert_match(/^hardware:\n  cpu:\n    cores: 4\n  memory:\n    memory: 8192\n  network:\n    net0:/, yaml)
  end

  def test_to_yaml_wrapper_section_omits_empty_subsections
    config = { vmid: 100, cores: 4 }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    refute_match(/memory:/, yaml)
    refute_match(/disks:/, yaml)
    refute_match(/network:/, yaml)
    assert_match(/hardware:\n  cpu:\n    cores: 4/, yaml)
  end

  def test_to_yaml_wrapper_section_omitted_when_all_subsections_empty
    config = { vmid: 100, name: "web" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    refute_match(/hardware:/, yaml)
  end

  def test_to_yaml_readonly_in_wrapper_subsection
    config = { vmid: 100, unused0: "local-lvm:vm-100-disk-2,size=10G" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })

    assert_match(/unused0:.*# read-only/, yaml)
  end

  def test_to_yaml_container_resources_wrapper
    config = { vmid: 200, cores: 2, memory: 512, rootfs: "local-lvm:vm-200-disk-0,size=8G" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :container,
                                            resource: { vmid: 200, node: "pve1", status: "running" })

    parsed = YAML.safe_load(yaml_without_comments(yaml))

    assert_equal 2, parsed.dig("resources", "cpu", "cores")
    assert_equal 512, parsed.dig("resources", "memory", "memory")
    assert parsed.dig("resources", "disks", "rootfs")
  end

  # ── from_yaml tests ────────────────────────────────────────────

  def test_from_yaml_flattens_nested_structure
    yaml = <<~YAML
      general:
        vmid: 100
        name: web
      hardware:
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

  def test_from_yaml_flattens_three_level_wrapper_nesting
    yaml = <<~YAML
      hardware:
        cpu:
          cores: 4
          sockets: 2
        memory:
          memory: 8192
          balloon: 4096
        disks:
          scsi0: "local-lvm:vm-100-disk-0,size=32G"
        network:
          net0: "virtio=AA:BB,bridge=vmbr0"
    YAML

    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :vm)

    assert_equal 4, result[:cores]
    assert_equal 2, result[:sockets]
    assert_equal 8192, result[:memory]
    assert_equal 4096, result[:balloon]
    assert_equal "local-lvm:vm-100-disk-0,size=32G", result[:scsi0]
    assert_equal "virtio=AA:BB,bridge=vmbr0", result[:net0]
  end

  def test_from_yaml_flattens_container_resources_wrapper
    yaml = <<~YAML
      resources:
        cpu:
          cores: 2
        memory:
          memory: 512
          swap: 256
        disks:
          rootfs: "local-lvm:vm-200-disk-0,size=8G"
    YAML

    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :container)

    assert_equal 2, result[:cores]
    assert_equal 512, result[:memory]
    assert_equal 256, result[:swap]
    assert_equal "local-lvm:vm-200-disk-0,size=8G", result[:rootfs]
  end

  def test_from_yaml_mixed_leaf_and_wrapper_sections
    yaml = <<~YAML
      general:
        vmid: 100
        name: web
      hardware:
        cpu:
          cores: 4
      options:
        onboot: true
    YAML

    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :vm)

    assert_equal 100, result[:vmid]
    assert_equal "web", result[:name]
    assert_equal 4, result[:cores]
    assert_equal true, result[:onboot]
  end

  # ── validate tests ─────────────────────────────────────────────

  def test_validate_returns_empty_for_valid_yaml
    yaml = <<~YAML
      general:
        name: web
      hardware:
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
      hardware:
        cpu:
          turbo: true
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("Unknown key 'turbo'") && e.include?("hardware/cpu") }
  end

  def test_validate_catches_syntax_error
    yaml = "general:\n  name: [invalid yaml"

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("YAML syntax error") }
  end

  def test_validate_accepts_dynamic_keys
    yaml = <<~YAML
      hardware:
        disks:
          scsi0: "local-lvm:vm-100-disk-0,size=32G"
          scsi1: "local-lvm:vm-100-disk-1,size=64G"
        network:
          net0: "virtio=AA:BB,bridge=vmbr0"
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert_empty errors
  end

  def test_validate_catches_unknown_subsection_in_wrapper
    yaml = <<~YAML
      hardware:
        gpu:
          model: nvidia
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("Unknown subsection 'gpu'") && e.include?("hardware") }
  end

  def test_validate_catches_unknown_key_in_wrapper_subsection
    yaml = <<~YAML
      hardware:
        cpu:
          turbo_boost: true
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert errors.any? { |e| e.include?("Unknown key 'turbo_boost'") && e.include?("hardware/cpu") }
  end

  def test_validate_valid_leaf_section
    yaml = <<~YAML
      options:
        onboot: true
        ostype: l26
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :vm)

    assert_empty errors
  end

  def test_validate_container_resources_wrapper
    yaml = <<~YAML
      resources:
        cpu:
          cores: 2
        memory:
          memory: 512
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :container)

    assert_empty errors
  end

  def test_validate_container_unknown_subsection_in_resources
    yaml = <<~YAML
      resources:
        gpu:
          model: nvidia
    YAML

    errors = Pvectl::ConfigSerializer.validate(yaml, type: :container)

    assert errors.any? { |e| e.include?("Unknown subsection 'gpu'") && e.include?("resources") }
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

  def test_readonly_violations_detects_unused_disk_change_in_wrapper
    original = { vmid: 100, unused0: "local-lvm:vm-100-disk-2,size=10G" }
    edited = { vmid: 100, unused0: "changed" }

    violations = Pvectl::ConfigSerializer.readonly_violations(original, edited, type: :vm)

    assert_includes violations, "unused0"
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

  # ── round-trip tests ───────────────────────────────────────────

  def test_round_trip_vm_config_with_wrapper_sections
    config = { vmid: 100, name: "web", cores: 4, memory: 8192,
               scsi0: "local-lvm:vm-100-disk-0,size=32G",
               net0: "virtio=AA:BB,bridge=vmbr0",
               onboot: true, ostype: "l26" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :vm, resource: { vmid: 100, node: "pve1", status: "running" })
    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :vm)

    assert_equal 100, result[:vmid]
    assert_equal "web", result[:name]
    assert_equal 4, result[:cores]
    assert_equal 8192, result[:memory]
    assert_equal "local-lvm:vm-100-disk-0,size=32G", result[:scsi0]
    assert_equal "virtio=AA:BB,bridge=vmbr0", result[:net0]
    assert_equal true, result[:onboot]
    assert_equal "l26", result[:ostype]
  end

  def test_round_trip_container_config_with_wrapper_sections
    config = { vmid: 200, hostname: "ct-web", cores: 2, memory: 512, swap: 256,
               rootfs: "local-lvm:vm-200-disk-0,size=8G",
               net0: "name=eth0,bridge=vmbr0",
               onboot: true, nameserver: "8.8.8.8" }
    yaml = Pvectl::ConfigSerializer.to_yaml(config, type: :container,
                                            resource: { vmid: 200, node: "pve1", status: "running" })
    result = Pvectl::ConfigSerializer.from_yaml(yaml, type: :container)

    assert_equal 200, result[:vmid]
    assert_equal "ct-web", result[:hostname]
    assert_equal 2, result[:cores]
    assert_equal 512, result[:memory]
    assert_equal 256, result[:swap]
    assert_equal "local-lvm:vm-200-disk-0,size=8G", result[:rootfs]
    assert_equal "name=eth0,bridge=vmbr0", result[:net0]
    assert_equal true, result[:onboot]
    assert_equal "8.8.8.8", result[:nameserver]
  end

  # ── to_nested tests ───────────────────────────────────────────

  def test_to_nested_creates_hardware_wrapper
    config = { cores: 4, memory: 8192 }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    assert_equal 4, result.dig(:hardware, :cpu, :cores)
    assert_equal 8192, result.dig(:hardware, :memory, :memory)
  end

  def test_to_nested_parses_network_values
    config = { net0: "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    net = result.dig(:hardware, :network, :net0)
    assert_equal "virtio", net[:model]
    assert_equal "AA:BB:CC:DD:EE:FF", net[:mac]
    assert_equal "vmbr0", net[:bridge]
    assert_equal true, net[:firewall]
  end

  def test_to_nested_parses_disk_values
    config = { scsi0: "local-lvm:vm-100-disk-0,size=32G,iothread=1" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    disk = result.dig(:hardware, :disks, :scsi0)
    assert_equal "local-lvm", disk[:storage]
    assert_equal "vm-100-disk-0", disk[:volume]
    assert_equal "32G", disk[:size]
    assert_equal true, disk[:iothread]
  end

  def test_to_nested_parses_agent_value
    config = { agent: "enabled=1,fstrim_cloned_disks=1" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    agent = result.dig(:options, :agent)
    assert_equal true, agent[:enabled]
    assert_equal true, agent[:fstrim_cloned_disks]
  end

  def test_to_nested_parses_boot_order
    config = { boot: "order=scsi0;net0" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    boot = result.dig(:options, :boot)
    assert_equal %w[scsi0 net0], boot[:order]
  end

  def test_to_nested_converts_boolean_values
    config = { onboot: 1, kvm: 1, ostype: "l26" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    assert_equal true, result.dig(:options, :onboot)
    assert_equal true, result.dig(:options, :kvm)
    assert_equal "l26", result.dig(:options, :ostype)
  end

  def test_to_nested_container_resources
    config = { cores: 2, memory: 512, rootfs: "local-lvm:vm-200-disk-0,size=8G" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :container)

    assert_equal 2, result.dig(:resources, :cpu, :cores)
    assert_equal 512, result.dig(:resources, :memory, :memory)

    rootfs = result.dig(:resources, :disks, :rootfs)
    assert_equal "local-lvm", rootfs[:storage]
    assert_equal "vm-200-disk-0", rootfs[:volume]
    assert_equal "8G", rootfs[:size]
  end

  def test_to_nested_omits_empty_sections
    config = { cores: 4 }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    assert result.key?(:hardware)
    assert result[:hardware].key?(:cpu)
    refute result[:hardware].key?(:memory)
    refute result[:hardware].key?(:network)
    refute result.key?(:general)
    # options is present because VM_DEFAULTS injects hotplug (parsed into capability map)
    assert result.key?(:options)
    expected_hotplug = { network: true, disk: true, usb: true, cpu: false, memory: false, cloudinit: false }
    assert_equal expected_hotplug, result[:options][:hotplug]
  end

  def test_to_nested_normalizes_cloudinit_volume
    config = { ide0: "local-lvm:vm-100-cloudinit,media=cdrom" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    disk = result.dig(:hardware, :disks, :ide0)
    assert_equal "local-lvm", disk[:storage]
    assert_equal "cloudinit", disk[:volume]
    assert_equal "cdrom", disk[:media]
  end

  def test_to_nested_preserves_regular_disk_volume
    config = { scsi0: "local-lvm:vm-100-disk-0,size=8G" }
    result = Pvectl::ConfigSerializer.to_nested(config, type: :vm)

    disk = result.dig(:hardware, :disks, :scsi0)
    assert_equal "vm-100-disk-0", disk[:volume]
  end

  # ── from_nested tests ───────────────────────────────────────

  def test_from_nested_serializes_network_back
    nested = {
      hardware: {
        network: {
          net0: { model: "virtio", mac: "AA:BB:CC:DD:EE:FF", bridge: "vmbr0", firewall: "1" }
        }
      }
    }
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    assert_equal "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1", result[:net0]
  end

  def test_from_nested_serializes_disk_back
    nested = {
      hardware: {
        disks: {
          scsi0: { storage: "local-lvm", volume: "vm-100-disk-0", size: "32G", iothread: "1" }
        }
      }
    }
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    assert_equal "local-lvm:vm-100-disk-0,size=32G,iothread=1", result[:scsi0]
  end

  def test_from_nested_normalizes_cloudinit_volume
    nested = {
      hardware: {
        disks: {
          ide0: { storage: "local-lvm", volume: "vm-100-cloudinit", media: "cdrom" }
        }
      }
    }
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    # Volume should be normalized from vm-100-cloudinit → cloudinit
    assert_equal "local-lvm:cloudinit,media=cdrom", result[:ide0]
  end

  def test_from_nested_serializes_boot_back
    nested = {
      options: {
        boot: { order: %w[scsi0 net0] }
      }
    }
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    assert_equal "order=scsi0;net0", result[:boot]
  end

  # ── complete_from_api tests ────────────────────────────────────

  def test_complete_from_api_fills_missing_disk_volume
    manifest = { scsi0: "local-lvm,iothread=1,size=9G" }
    api      = { scsi0: "local-lvm:vm-100-disk-0,iothread=1,size=9G" }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    assert_equal "local-lvm:vm-100-disk-0,iothread=1,size=9G", result[:scsi0]
  end

  def test_complete_from_api_fills_missing_net_mac
    manifest = { net0: "virtio,bridge=vmbr0,firewall=1" }
    api      = { net0: "virtio=BC:24:11:16:54:F1,bridge=vmbr0,firewall=1" }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    assert_equal "virtio=BC:24:11:16:54:F1,bridge=vmbr0,firewall=1", result[:net0]
  end

  def test_complete_from_api_fills_missing_cloudinit_size
    manifest = { ide0: "local-lvm:cloudinit,media=cdrom" }
    api      = { ide0: "local-lvm:cloudinit,media=cdrom,size=4M" }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    assert_equal "local-lvm:cloudinit,media=cdrom,size=4M", result[:ide0]
  end

  def test_complete_from_api_preserves_manifest_overrides
    manifest = { net0: "virtio,bridge=vmbr1,firewall=1" }
    api      = { net0: "virtio=BC:24:11:16:54:F1,bridge=vmbr0,firewall=1" }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    # MAC filled from API, bridge overridden by manifest
    assert_includes result[:net0], "BC:24:11:16:54:F1"
    assert_includes result[:net0], "bridge=vmbr1"
    refute_includes result[:net0], "bridge=vmbr0"
  end

  def test_complete_from_api_skips_non_complex_keys
    manifest = { cores: 8, memory: 4096 }
    api      = { cores: 4, memory: 2048 }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    # Non-complex keys are kept from manifest, not merged
    assert_equal 8, result[:cores]
    assert_equal 4096, result[:memory]
  end

  def test_complete_from_api_passes_through_new_keys
    manifest = { scsi1: "local-lvm,size=16G" }
    api      = {} # scsi1 doesn't exist in API

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    # Key not in API — kept as-is from manifest
    assert_equal "local-lvm,size=16G", result[:scsi1]
  end

  def test_complete_from_api_coerces_numeric_strings_to_integers
    manifest = { memory: "2048", cores: "4" }
    api      = { memory: 2048, cores: 4 }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    assert_equal 2048, result[:memory]
    assert_equal 4, result[:cores]
    assert result[:memory].is_a?(Integer)
  end

  def test_complete_from_api_fills_missing_kv_subproperties
    manifest = { smbios1: "uuid=custom-uuid" }
    api      = { smbios1: "uuid=e682a07a-0924-4b15-a1b1-4f83e3e41448" }

    result = Pvectl::ConfigSerializer.complete_from_api(manifest, api, type: :vm)

    # Manifest overrides uuid
    assert_equal "uuid=custom-uuid", result[:smbios1]
  end

  def test_from_nested_round_trip_vm
    original = {
      vmid: 100, name: "web", cores: 4, memory: 8192,
      scsi0: "local-lvm:vm-100-disk-0,size=32G",
      net0: "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1",
      boot: "order=scsi0;net0",
      agent: "enabled=1,fstrim_cloned_disks=1",
      onboot: 1, ostype: "l26"
    }

    nested = Pvectl::ConfigSerializer.to_nested(original, type: :vm)
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    # VM_DEFAULTS injects hotplug; both to_nested and from_nested inject defaults
    assert_equal original.merge(hotplug: "network,disk,usb"), result
  end

  def test_from_nested_round_trip_container
    original = {
      vmid: 200, hostname: "ct-web", cores: 2, memory: 512, swap: 256,
      rootfs: "local-lvm:vm-200-disk-0,size=8G",
      net0: "name=eth0,bridge=vmbr0,firewall=1,hwaddr=AA:BB:CC:DD:EE:FF,ip=dhcp",
      onboot: 1, features: "nesting=1,keyctl=1"
    }

    nested = Pvectl::ConfigSerializer.to_nested(original, type: :container)
    result = Pvectl::ConfigSerializer.from_nested(nested, type: :container)

    assert_equal original, result
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
