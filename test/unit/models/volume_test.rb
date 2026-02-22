# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Models
    class VolumeTest < Minitest::Test
      def test_initializes_from_config_attributes
        vol = Volume.new(
          name: "scsi0",
          storage: "local-lvm",
          volume_id: "vm-100-disk-0",
          size: "32G",
          format: "raw",
          resource_type: "vm",
          resource_id: 100,
          node: "pve1",
          discard: "on",
          ssd: 1,
          iothread: 1
        )

        assert_equal "scsi0", vol.name
        assert_equal "local-lvm", vol.storage
        assert_equal "vm-100-disk-0", vol.volume_id
        assert_equal "32G", vol.size
        assert_equal "raw", vol.format
        assert_equal "vm", vol.resource_type
        assert_equal 100, vol.resource_id
        assert_equal "pve1", vol.node
        assert_equal "on", vol.discard
        assert_equal 1, vol.ssd
        assert_equal 1, vol.iothread
      end

      def test_initializes_from_storage_attributes
        vol = Volume.new(
          storage: "local-lvm",
          volume_id: "vm-100-disk-0",
          volid: "local-lvm:vm-100-disk-0",
          size: "32G",
          format: "raw",
          resource_type: "vm",
          resource_id: 100,
          node: "pve1",
          content: "images"
        )

        assert_equal "local-lvm:vm-100-disk-0", vol.volid
        assert_equal "images", vol.content
        assert_nil vol.name
      end

      def test_volid_constructed_when_not_provided
        vol = Volume.new(
          storage: "local-lvm",
          volume_id: "vm-100-disk-0",
          node: "pve1"
        )

        assert_equal "local-lvm:vm-100-disk-0", vol.volid
      end

      def test_volid_nil_when_no_storage_or_volume_id
        vol = Volume.new(name: "scsi0", node: "pve1")

        assert_nil vol.volid
      end

      def test_vm_query
        vol = Volume.new(resource_type: "vm", node: "pve1")
        assert vol.vm?
        refute vol.container?
      end

      def test_container_query
        vol = Volume.new(resource_type: "ct", node: "pve1")
        assert vol.container?
        refute vol.vm?
      end
    end
  end
end
