# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class SharedConfigParsersTest < Minitest::Test
      # Test harness that includes the mixin
      class ParserHost
        include SharedConfigParsers

        attr_accessor :options

        def initialize(options = {})
          @options = options
        end
      end

      # --- parse_vm_disks ---

      def test_parse_vm_disks_with_single_disk
        host = ParserHost.new(disk: ["storage=local-lvm,size=32G"])
        result = host.parse_vm_disks

        assert_equal 1, result.length
        assert_equal "local-lvm", result[0][:storage]
        assert_equal "32G", result[0][:size]
      end

      def test_parse_vm_disks_with_multiple_disks
        host = ParserHost.new(disk: [
          "storage=local-lvm,size=32G",
          "storage=ceph,size=100G,format=qcow2"
        ])
        result = host.parse_vm_disks

        assert_equal 2, result.length
        assert_equal "local-lvm", result[0][:storage]
        assert_equal "ceph", result[1][:storage]
        assert_equal "qcow2", result[1][:format]
      end

      def test_parse_vm_disks_with_nil_wraps_in_empty_array
        host = ParserHost.new(disk: nil)
        result = host.parse_vm_disks

        assert_equal [], result
      end

      # --- parse_vm_nets ---

      def test_parse_vm_nets_with_network_config
        host = ParserHost.new(net: ["bridge=vmbr0,model=virtio,tag=100"])
        result = host.parse_vm_nets

        assert_equal 1, result.length
        assert_equal "vmbr0", result[0][:bridge]
        assert_equal "virtio", result[0][:model]
        assert_equal "100", result[0][:tag]
      end

      def test_parse_vm_nets_with_multiple_nets
        host = ParserHost.new(net: [
          "bridge=vmbr0",
          "bridge=vmbr1,tag=200"
        ])
        result = host.parse_vm_nets

        assert_equal 2, result.length
        assert_equal "vmbr0", result[0][:bridge]
        assert_equal "vmbr1", result[1][:bridge]
      end

      # --- parse_vm_cloud_init ---

      def test_parse_vm_cloud_init_returns_proxmox_params
        host = ParserHost.new("cloud-init": "user=admin,ip=dhcp")
        result = host.parse_vm_cloud_init

        assert_equal "admin", result[:ciuser]
        assert_equal "ip=dhcp", result[:ipconfig0]
      end

      def test_parse_vm_cloud_init_with_password_and_nameserver
        host = ParserHost.new("cloud-init": "user=root,password=secret,nameserver=8.8.8.8")
        result = host.parse_vm_cloud_init

        assert_equal "root", result[:ciuser]
        assert_equal "secret", result[:cipassword]
        assert_equal "8.8.8.8", result[:nameserver]
      end

      # --- parse_ct_mountpoints ---

      def test_parse_ct_mountpoints_with_single_mountpoint
        host = ParserHost.new(mp: ["storage=local-lvm,size=32G,mp=/mnt/data"])
        result = host.parse_ct_mountpoints

        assert_equal 1, result.length
        assert_equal "local-lvm", result[0][:storage]
        assert_equal "32G", result[0][:size]
        assert_equal "/mnt/data", result[0][:mp]
      end

      def test_parse_ct_mountpoints_with_multiple_mountpoints
        host = ParserHost.new(mp: [
          "storage=local-lvm,size=32G,mp=/mnt/data",
          "storage=ceph,size=100G,mp=/mnt/backup"
        ])
        result = host.parse_ct_mountpoints

        assert_equal 2, result.length
        assert_equal "/mnt/data", result[0][:mp]
        assert_equal "/mnt/backup", result[1][:mp]
      end

      # --- parse_ct_nets ---

      def test_parse_ct_nets_with_lxc_network_config
        host = ParserHost.new(net: ["bridge=vmbr0,name=eth0,ip=dhcp"])
        result = host.parse_ct_nets

        assert_equal 1, result.length
        assert_equal "vmbr0", result[0][:bridge]
        assert_equal "eth0", result[0][:name]
        assert_equal "dhcp", result[0][:ip]
      end

      def test_parse_ct_nets_with_multiple_lxc_nets
        host = ParserHost.new(net: [
          "bridge=vmbr0,name=eth0,ip=dhcp",
          "bridge=vmbr1,name=eth1,ip=10.0.0.5/24,gw=10.0.0.1"
        ])
        result = host.parse_ct_nets

        assert_equal 2, result.length
        assert_equal "vmbr0", result[0][:bridge]
        assert_equal "vmbr1", result[1][:bridge]
        assert_equal "10.0.0.5/24", result[1][:ip]
      end

      # --- build_vm_config_params ---

      def test_build_vm_config_params_extracts_correct_keys
        host = ParserHost.new(
          cores: 4, sockets: 2, "cpu-type": "host",
          numa: true, memory: 8192, balloon: 4096,
          scsihw: "virtio-scsi-pci", cdrom: "local:iso/ubuntu.iso",
          bios: "ovmf", "boot-order": "scsi0;net0",
          machine: "q35", efidisk: "local-lvm:1",
          agent: true, ostype: "l26", tags: "prod;web"
        )
        result = host.build_vm_config_params

        assert_equal 4, result[:cores]
        assert_equal 2, result[:sockets]
        assert_equal "host", result[:cpu_type]
        assert_equal true, result[:numa]
        assert_equal 8192, result[:memory]
        assert_equal 4096, result[:balloon]
        assert_equal "virtio-scsi-pci", result[:scsihw]
        assert_equal "local:iso/ubuntu.iso", result[:cdrom]
        assert_equal "ovmf", result[:bios]
        assert_equal "scsi0;net0", result[:boot_order]
        assert_equal "q35", result[:machine]
        assert_equal "local-lvm:1", result[:efidisk]
        assert_equal true, result[:agent]
        assert_equal "l26", result[:ostype]
        assert_equal "prod;web", result[:tags]
      end

      def test_build_vm_config_params_omits_nil_values
        host = ParserHost.new(cores: 4, memory: 2048)
        result = host.build_vm_config_params

        assert_equal 4, result[:cores]
        assert_equal 2048, result[:memory]
        refute result.key?(:sockets)
        refute result.key?(:bios)
        refute result.key?(:disks)
        refute result.key?(:nets)
        refute result.key?(:cloud_init)
      end

      def test_build_vm_config_params_parses_disks_and_nets
        host = ParserHost.new(
          cores: 2,
          disk: ["storage=local-lvm,size=32G"],
          net: ["bridge=vmbr0"]
        )
        result = host.build_vm_config_params

        assert_equal 1, result[:disks].length
        assert_equal "local-lvm", result[:disks][0][:storage]
        assert_equal 1, result[:nets].length
        assert_equal "vmbr0", result[:nets][0][:bridge]
      end

      def test_build_vm_config_params_parses_cloud_init
        host = ParserHost.new("cloud-init": "user=admin,ip=dhcp")
        result = host.build_vm_config_params

        assert_equal "admin", result[:cloud_init][:ciuser]
      end

      # --- build_ct_config_params ---

      def test_build_ct_config_params_extracts_correct_keys
        host = ParserHost.new(
          cores: 2, memory: 2048, swap: 1024,
          tags: "dev", features: "nesting=1",
          password: "secret", "ssh-public-keys": "/path/to/keys",
          onboot: true, startup: "order=1"
        )
        result = host.build_ct_config_params

        assert_equal 2, result[:cores]
        assert_equal 2048, result[:memory]
        assert_equal 1024, result[:swap]
        assert_equal "dev", result[:tags]
        assert_equal "nesting=1", result[:features]
        assert_equal "secret", result[:password]
        assert_equal "/path/to/keys", result[:ssh_public_keys]
        assert_equal true, result[:onboot]
        assert_equal "order=1", result[:startup]
      end

      def test_build_ct_config_params_sets_privileged_flag
        host = ParserHost.new(privileged: true)
        result = host.build_ct_config_params

        assert_equal true, result[:privileged]
      end

      def test_build_ct_config_params_omits_privileged_when_not_set
        host = ParserHost.new(cores: 1)
        result = host.build_ct_config_params

        refute result.key?(:privileged)
      end

      def test_build_ct_config_params_parses_rootfs
        host = ParserHost.new(rootfs: "storage=local-lvm,size=8G")
        result = host.build_ct_config_params

        assert_equal "local-lvm", result[:rootfs][:storage]
        assert_equal "8G", result[:rootfs][:size]
      end

      def test_build_ct_config_params_parses_mountpoints_and_nets
        host = ParserHost.new(
          mp: ["storage=local-lvm,size=32G,mp=/mnt/data"],
          net: ["bridge=vmbr0,name=eth0,ip=dhcp"]
        )
        result = host.build_ct_config_params

        assert_equal 1, result[:mountpoints].length
        assert_equal "/mnt/data", result[:mountpoints][0][:mp]
        assert_equal 1, result[:nets].length
        assert_equal "vmbr0", result[:nets][0][:bridge]
      end

      def test_build_ct_config_params_omits_nil_values
        host = ParserHost.new(cores: 2)
        result = host.build_ct_config_params

        assert_equal 2, result[:cores]
        refute result.key?(:memory)
        refute result.key?(:swap)
        refute result.key?(:rootfs)
        refute result.key?(:mountpoints)
        refute result.key?(:nets)
      end
    end
  end
end
