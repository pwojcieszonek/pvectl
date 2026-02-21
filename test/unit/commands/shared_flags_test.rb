# frozen_string_literal: true

require "test_helper"

class SharedFlagsTest < Minitest::Test
  def test_lifecycle_defines_timeout_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:timeout) },
           "Should define --timeout flag"
  end

  def test_lifecycle_defines_async_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:async) },
           "Should define --async switch"
  end

  def test_lifecycle_defines_wait_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:wait) },
           "Should define --wait switch"
  end

  def test_lifecycle_defines_all_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:all) },
           "Should define --all switch"
  end

  def test_lifecycle_defines_node_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:node) },
           "Should define --node flag"
  end

  def test_lifecycle_defines_yes_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:yes) },
           "Should define --yes switch"
  end

  def test_lifecycle_defines_fail_fast_switch
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.switches.any? { |s| s[:names].include?(:"fail-fast") },
           "Should define --fail-fast switch"
  end

  def test_lifecycle_defines_selector_flag
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    assert mock_command.flags.any? { |f| f[:names].include?(:selector) },
           "Should define --selector flag"
  end

  def test_lifecycle_defines_exactly_eight_options
    mock_command = MockGLICommand.new
    Pvectl::Commands::SharedFlags.lifecycle(mock_command)

    total = mock_command.flags.size + mock_command.switches.size
    assert_equal 8, total, "Should define exactly 8 lifecycle flags/switches (got #{total})"
  end

  # --- common_config tests ---

  def test_common_config_defines_cores_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:cores) }, "Should define --cores flag"
  end

  def test_common_config_defines_memory_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:memory) }, "Should define --memory flag"
  end

  def test_common_config_defines_net_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    net_flag = cmd.flags.find { |f| f[:names].include?(:net) }
    assert net_flag, "Should define --net flag"
    assert net_flag[:multiple], "Net flag should be repeatable"
  end

  def test_common_config_defines_tags_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:tags) }, "Should define --tags flag"
  end

  def test_common_config_defines_node_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:node) }, "Should define --node flag"
  end

  def test_common_config_defines_start_switch
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    assert cmd.switches.any? { |s| s[:names].include?(:start) }, "Should define --start switch"
  end

  def test_common_config_defines_exactly_six_options
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.common_config(cmd)

    total = cmd.flags.size + cmd.switches.size
    assert_equal 6, total, "Should define exactly 6 common_config flags/switches (got #{total})"
  end

  # --- vm_config tests ---

  def test_vm_config_defines_sockets_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:sockets) }, "Should define --sockets flag"
  end

  def test_vm_config_defines_cpu_type_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:"cpu-type") }, "Should define --cpu-type flag"
  end

  def test_vm_config_defines_numa_switch
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.switches.any? { |s| s[:names].include?(:numa) }, "Should define --numa switch"
  end

  def test_vm_config_defines_balloon_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:balloon) }, "Should define --balloon flag"
  end

  def test_vm_config_defines_disk_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    disk_flag = cmd.flags.find { |f| f[:names].include?(:disk) }
    assert disk_flag, "Should define --disk flag"
    assert disk_flag[:multiple], "Disk flag should be repeatable"
  end

  def test_vm_config_defines_scsihw_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:scsihw) }, "Should define --scsihw flag"
  end

  def test_vm_config_defines_cdrom_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:cdrom) }, "Should define --cdrom flag"
  end

  def test_vm_config_defines_bios_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:bios) }, "Should define --bios flag"
  end

  def test_vm_config_defines_boot_order_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:"boot-order") }, "Should define --boot-order flag"
  end

  def test_vm_config_defines_machine_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:machine) }, "Should define --machine flag"
  end

  def test_vm_config_defines_efidisk_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:efidisk) }, "Should define --efidisk flag"
  end

  def test_vm_config_defines_cloud_init_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:"cloud-init") }, "Should define --cloud-init flag"
  end

  def test_vm_config_defines_agent_switch
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.switches.any? { |s| s[:names].include?(:agent) }, "Should define --agent switch"
  end

  def test_vm_config_defines_ostype_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:ostype) }, "Should define --ostype flag"
  end

  def test_vm_config_defines_exactly_fourteen_options
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.vm_config(cmd)

    total = cmd.flags.size + cmd.switches.size
    assert_equal 14, total, "Should define exactly 14 vm_config flags/switches (got #{total})"
  end

  # --- container_config tests ---

  def test_container_config_defines_rootfs_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:rootfs) }, "Should define --rootfs flag"
  end

  def test_container_config_defines_mp_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    mp_flag = cmd.flags.find { |f| f[:names].include?(:mp) }
    assert mp_flag, "Should define --mp flag"
    assert mp_flag[:multiple], "Mp flag should be repeatable"
  end

  def test_container_config_defines_swap_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:swap) }, "Should define --swap flag"
  end

  def test_container_config_defines_privileged_switch
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.switches.any? { |s| s[:names].include?(:privileged) }, "Should define --privileged switch"
  end

  def test_container_config_defines_features_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:features) }, "Should define --features flag"
  end

  def test_container_config_defines_password_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:password) }, "Should define --password flag"
  end

  def test_container_config_defines_ssh_public_keys_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:"ssh-public-keys") }, "Should define --ssh-public-keys flag"
  end

  def test_container_config_defines_onboot_switch
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.switches.any? { |s| s[:names].include?(:onboot) }, "Should define --onboot switch"
  end

  def test_container_config_defines_startup_flag
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    assert cmd.flags.any? { |f| f[:names].include?(:startup) }, "Should define --startup flag"
  end

  def test_container_config_defines_exactly_nine_options
    cmd = MockGLICommand.new
    Pvectl::Commands::SharedFlags.container_config(cmd)

    total = cmd.flags.size + cmd.switches.size
    assert_equal 9, total, "Should define exactly 9 container_config flags/switches (got #{total})"
  end

  # Minimal mock for GLI::Command flag/switch API
  class MockGLICommand
    attr_reader :flags, :switches

    def initialize
      @flags = []
      @switches = []
      @last_desc = nil
    end

    def desc(text)
      @last_desc = text
    end

    def default_value(_val); end

    def flag(names, **opts)
      @flags << { names: Array(names).flatten, desc: @last_desc, **opts }
      @last_desc = nil
    end

    def switch(names, **opts)
      @switches << { names: Array(names).flatten, desc: @last_desc, **opts }
      @last_desc = nil
    end
  end
end
