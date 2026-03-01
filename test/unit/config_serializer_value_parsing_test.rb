# frozen_string_literal: true

require "test_helper"

class ConfigSerializerValueParsingTest < Minitest::Test
  # ── parse_vm_net_value tests ──────────────────────────────────

  def test_parse_vm_net_value
    result = parse_vm_net("virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1")

    assert_equal "virtio", result[:model]
    assert_equal "AA:BB:CC:DD:EE:FF", result[:mac]
    assert_equal "vmbr0", result[:bridge]
    assert_equal "1", result[:firewall]
  end

  def test_serialize_vm_net_value
    hash = { model: "virtio", mac: "AA:BB:CC:DD:EE:FF", bridge: "vmbr0", firewall: "1" }
    result = serialize_vm_net(hash)

    assert_equal "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1", result
  end

  def test_vm_net_round_trip
    original = "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0,firewall=1,tag=100"
    parsed = parse_vm_net(original)
    serialized = serialize_vm_net(parsed)
    reparsed = parse_vm_net(serialized)

    assert_equal parsed, reparsed
  end

  def test_serialize_vm_net_value_without_mac
    hash = { model: "e1000" }
    result = serialize_vm_net(hash)

    assert_equal "e1000", result
  end

  # ── parse_disk_value tests ────────────────────────────────────

  def test_parse_disk_value
    result = parse_disk("local-lvm:vm-100-disk-0,size=32G,iothread=1")

    assert_equal "local-lvm", result[:storage]
    assert_equal "vm-100-disk-0", result[:volume]
    assert_equal "32G", result[:size]
    assert_equal "1", result[:iothread]
  end

  def test_disk_round_trip
    original = "local-lvm:vm-100-disk-0,size=32G,iothread=1,discard=on"
    parsed = parse_disk(original)
    serialized = serialize_disk(parsed)
    reparsed = parse_disk(serialized)

    assert_equal parsed, reparsed
  end

  def test_parse_disk_value_without_volume
    result = parse_disk("none")

    assert_equal "none", result[:storage]
    refute result.key?(:volume)
  end

  # ── parse_kv_value tests ──────────────────────────────────────

  def test_parse_kv_value
    result = parse_kv("enabled=1,fstrim_cloned_disks=1,type=virtio")

    assert_equal "1", result[:enabled]
    assert_equal "1", result[:fstrim_cloned_disks]
    assert_equal "virtio", result[:type]
  end

  def test_parse_kv_value_bare_value_with_default_key
    result = Pvectl::ConfigSerializer.send(:parse_kv_value, "1", default_key: :enabled)

    assert_equal({ enabled: "1" }, result)
  end

  def test_parse_kv_value_bare_value_mixed_with_kv_pairs
    result = Pvectl::ConfigSerializer.send(:parse_kv_value, "1,fstrim_cloned_disks=1,type=virtio",
                                           default_key: :enabled)

    assert_equal "1", result[:enabled]
    assert_equal "1", result[:fstrim_cloned_disks]
    assert_equal "virtio", result[:type]
  end

  # ── parse_agent_value tests ─────────────────────────────────

  def test_parse_agent_value_bare_1
    result = Pvectl::ConfigSerializer.send(:parse_agent_value, "1")

    assert_equal "1", result[:enabled]
    assert_equal "0", result[:fstrim_cloned_disks]
    assert_equal "1", result[:"freeze-fs-on-backup"]
    assert_equal "virtio", result[:type]
  end

  def test_parse_agent_value_with_explicit_properties
    result = Pvectl::ConfigSerializer.send(:parse_agent_value, "enabled=1,fstrim_cloned_disks=1")

    assert_equal "1", result[:enabled]
    assert_equal "1", result[:fstrim_cloned_disks]
    assert_equal "1", result[:"freeze-fs-on-backup"]
    assert_equal "virtio", result[:type]
  end

  def test_serialize_agent_value_only_enabled
    hash = { enabled: "1", fstrim_cloned_disks: "0", :"freeze-fs-on-backup" => "1", type: "virtio" }
    result = Pvectl::ConfigSerializer.send(:serialize_agent_value, hash)

    assert_equal "enabled=1", result
  end

  def test_serialize_agent_value_with_non_defaults
    hash = { enabled: "1", fstrim_cloned_disks: "1", :"freeze-fs-on-backup" => "0", type: "virtio" }
    result = Pvectl::ConfigSerializer.send(:serialize_agent_value, hash)

    assert_includes result, "enabled=1"
    assert_includes result, "fstrim_cloned_disks=1"
    assert_includes result, "freeze-fs-on-backup=0"
    refute_includes result, "type=virtio"
  end

  def test_agent_round_trip_via_to_nested
    flat_config = { agent: "1,fstrim_cloned_disks=1" }
    nested = Pvectl::ConfigSerializer.to_nested(flat_config, type: :vm)
    flat_back = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)

    # Round-trip produces equivalent Proxmox config (only non-default values)
    assert_includes flat_back[:agent], "enabled=1"
    assert_includes flat_back[:agent], "fstrim_cloned_disks=1"
  end

  def test_agent_bare_1_round_trip_via_to_nested
    flat_config = { agent: "1" }
    nested = Pvectl::ConfigSerializer.to_nested(flat_config, type: :vm)

    # Full agent config with defaults filled in
    assert_equal "1", nested[:options][:agent][:enabled]
    assert_equal "0", nested[:options][:agent][:fstrim_cloned_disks]
    assert_equal "1", nested[:options][:agent][:"freeze-fs-on-backup"]
    assert_equal "virtio", nested[:options][:agent][:type]

    flat_back = Pvectl::ConfigSerializer.from_nested(nested, type: :vm)
    # Only non-default: enabled=1
    assert_equal "enabled=1", flat_back[:agent]
  end

  # ── VM defaults injection tests ────────────────────────────

  def test_to_nested_injects_hotplug_default
    flat_config = { cores: 4 }
    nested = Pvectl::ConfigSerializer.to_nested(flat_config, type: :vm)

    assert_equal "network,disk,usb", nested[:options][:hotplug]
  end

  def test_to_nested_preserves_explicit_hotplug
    flat_config = { cores: 4, hotplug: "0" }
    nested = Pvectl::ConfigSerializer.to_nested(flat_config, type: :vm)

    assert_equal "0", nested[:options][:hotplug]
  end

  def test_hotplug_default_round_trip_no_false_diff
    # Simulate push flow: both sides go through to_nested/from_nested
    api_config = { cores: 4 }
    manifest_nested = Pvectl::ConfigSerializer.to_nested(api_config, type: :vm)
    manifest_flat = Pvectl::ConfigSerializer.from_nested(manifest_nested, type: :vm)

    original_nested = Pvectl::ConfigSerializer.to_nested(api_config, type: :vm)
    original_flat = Pvectl::ConfigSerializer.from_nested(original_nested, type: :vm)

    diff = Pvectl::ConfigSerializer.diff(original_flat, manifest_flat)

    assert_empty diff[:changed]
    assert_empty diff[:added]
    assert_empty diff[:removed]
  end

  def test_to_nested_does_not_inject_defaults_for_container
    flat_config = { cores: 4 }
    nested = Pvectl::ConfigSerializer.to_nested(flat_config, type: :container)

    # Container has no hotplug
    refute nested.dig(:options, :hotplug)
  end

  def test_kv_round_trip
    original = "enabled=1,fstrim_cloned_disks=1"
    parsed = parse_kv(original)
    serialized = serialize_kv(parsed)
    reparsed = parse_kv(serialized)

    assert_equal parsed, reparsed
  end

  # ── parse_boot_value tests ────────────────────────────────────

  def test_parse_boot_value
    result = parse_boot("order=scsi0;net0")

    assert_equal %w[scsi0 net0], result[:order]
  end

  def test_boot_round_trip
    original = "order=scsi0;net0;ide2"
    parsed = parse_boot(original)
    serialized = serialize_boot(parsed)
    reparsed = parse_boot(serialized)

    assert_equal parsed, reparsed
  end

  def test_parse_boot_value_single_device
    result = parse_boot("order=scsi0")

    assert_equal %w[scsi0], result[:order]
  end

  # ── CT-specific parsing tests ─────────────────────────────────

  def test_parse_ct_net_value
    # CT network uses generic key=value format (no model=mac first part)
    result = parse_kv("name=eth0,bridge=vmbr0,firewall=1,hwaddr=AA:BB:CC:DD:EE:FF,ip=dhcp")

    assert_equal "eth0", result[:name]
    assert_equal "vmbr0", result[:bridge]
    assert_equal "1", result[:firewall]
    assert_equal "AA:BB:CC:DD:EE:FF", result[:hwaddr]
    assert_equal "dhcp", result[:ip]
  end

  def test_ct_mount_value
    result = parse_disk("local-lvm:vm-200-disk-0,size=8G")

    assert_equal "local-lvm", result[:storage]
    assert_equal "vm-200-disk-0", result[:volume]
    assert_equal "8G", result[:size]
  end

  # ── find_complex_key tests ────────────────────────────────────

  def test_find_complex_key_vm_net
    spec = find_complex(:net0, :vm)

    assert spec
    assert_equal :parse_vm_net_value, spec[:parser]
    assert_equal :serialize_vm_net_value, spec[:serializer]
  end

  def test_find_complex_key_vm_disk
    spec = find_complex(:scsi0, :vm)

    assert spec
    assert_equal :parse_disk_value, spec[:parser]
  end

  def test_find_complex_key_vm_boot
    spec = find_complex(:boot, :vm)

    assert spec
    assert_equal :parse_boot_value, spec[:parser]
  end

  def test_find_complex_key_container_net
    spec = find_complex(:net0, :container)

    assert spec
    assert_equal :parse_kv_value, spec[:parser]
  end

  def test_find_complex_key_container_rootfs
    spec = find_complex(:rootfs, :container)

    assert spec
    assert_equal :parse_disk_value, spec[:parser]
  end

  def test_find_complex_key_container_mp
    spec = find_complex(:mp0, :container)

    assert spec
    assert_equal :parse_disk_value, spec[:parser]
  end

  def test_find_complex_key_container_features
    spec = find_complex(:features, :container)

    assert spec
    assert_equal :parse_kv_value, spec[:parser]
  end

  def test_find_complex_key_returns_nil_for_simple_keys
    assert_nil find_complex(:cores, :vm)
    assert_nil find_complex(:memory, :vm)
    assert_nil find_complex(:name, :vm)
    assert_nil find_complex(:onboot, :container)
    assert_nil find_complex(:hostname, :container)
  end

  private

  # Convenience wrappers to call private methods via send
  def parse_vm_net(string)
    Pvectl::ConfigSerializer.send(:parse_vm_net_value, string)
  end

  def serialize_vm_net(hash)
    Pvectl::ConfigSerializer.send(:serialize_vm_net_value, hash)
  end

  def parse_disk(string)
    Pvectl::ConfigSerializer.send(:parse_disk_value, string)
  end

  def serialize_disk(hash)
    Pvectl::ConfigSerializer.send(:serialize_disk_value, hash)
  end

  def parse_kv(string)
    Pvectl::ConfigSerializer.send(:parse_kv_value, string)
  end

  def serialize_kv(hash)
    Pvectl::ConfigSerializer.send(:serialize_kv_value, hash)
  end

  def parse_boot(string)
    Pvectl::ConfigSerializer.send(:parse_boot_value, string)
  end

  def serialize_boot(hash)
    Pvectl::ConfigSerializer.send(:serialize_boot_value, hash)
  end

  def find_complex(key, type)
    Pvectl::ConfigSerializer.send(:find_complex_key, key, type)
  end
end
