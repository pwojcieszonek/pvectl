# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class SetVolumeTest < Minitest::Test
      def build_mock_repo(config: nil, resize_called: nil, update_called: nil)
        default_config = { scsi0: "local-lvm:vm-100-disk-0,size=32G,cache=none" }
        repo = Object.new

        repo.define_singleton_method(:fetch_config) { |_node, _id| config || default_config }
        repo.define_singleton_method(:get) { |id| Models::Vm.new(vmid: id, node: "pve1", status: "running") }

        repo.define_singleton_method(:resize) do |id, node, disk:, size:|
          resize_called&.call(id, node, disk, size)
        end

        repo.define_singleton_method(:update) do |id, node, params|
          update_called&.call(id, node, params)
        end

        repo
      end

      def test_size_only_delegates_to_resize
        resize_args = nil
        repo = build_mock_repo(
          resize_called: ->(id, node, disk, size) { resize_args = { id: id, node: node, disk: disk, size: size } }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "size" => "+10G" }, node: "pve1")

        assert result.successful?
        assert_kind_of Models::VolumeOperationResult, result
        assert resize_args, "resize should have been called"
        assert_equal "+10G", resize_args[:size]
      end

      def test_config_only_updates_config_string
        update_args = nil
        repo = build_mock_repo(
          update_called: ->(_id, _node, params) { update_args = params }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "cache" => "writeback" }, node: "pve1")

        assert result.successful?
        assert update_args, "update should have been called"
        # The scsi0 config string should contain cache=writeback
        assert_match(/cache=writeback/, update_args[:scsi0].to_s)
      end

      def test_mixed_size_and_config
        resize_called = false
        update_called = false
        repo = build_mock_repo(
          resize_called: ->(_id, _node, _disk, _size) { resize_called = true },
          update_called: ->(_id, _node, _params) { update_called = true }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(
          id: 100, disk: "scsi0",
          params: { "size" => "+10G", "cache" => "writeback" },
          node: "pve1"
        )

        assert result.successful?
        assert resize_called, "resize should have been called"
        assert update_called, "update should have been called"
      end

      def test_disk_not_found
        repo = build_mock_repo(config: { ide0: "some-other-disk,size=10G" })

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "size" => "+10G" }, node: "pve1")

        assert result.failed?
        assert_match(/not found/, result.error)
      end

      def test_invalid_size_format
        repo = build_mock_repo

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "size" => "abc" }, node: "pve1")

        assert result.failed?
        assert_match(/Invalid size format/, result.error)
      end

      def test_config_replaces_existing_key
        update_args = nil
        repo = build_mock_repo(
          update_called: ->(_id, _node, params) { update_args = params }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "cache" => "writeback" }, node: "pve1")

        assert result.successful?
        # Original had cache=none, now should be cache=writeback
        refute_match(/cache=none/, update_args[:scsi0].to_s)
        assert_match(/cache=writeback/, update_args[:scsi0].to_s)
      end

      def test_config_adds_new_key
        update_args = nil
        repo = build_mock_repo(
          update_called: ->(_id, _node, params) { update_args = params }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "discard" => "on" }, node: "pve1")

        assert result.successful?
        assert_match(/discard=on/, update_args[:scsi0].to_s)
      end

      def test_preserves_base_volume_id
        update_args = nil
        repo = build_mock_repo(
          update_called: ->(_id, _node, params) { update_args = params }
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "cache" => "writeback" }, node: "pve1")

        assert result.successful?
        # Should preserve the base "local-lvm:vm-100-disk-0" part
        assert update_args[:scsi0].to_s.start_with?("local-lvm:vm-100-disk-0")
      end

      def test_result_has_volume_info
        repo = build_mock_repo(
          update_called: ->(_id, _node, _params) {}
        )

        service = SetVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", params: { "cache" => "writeback" }, node: "pve1")

        assert_equal :set, result.operation
        assert_equal "scsi0", result.volume.name
        assert_equal "vm", result.volume.resource_type
        assert_equal 100, result.volume.resource_id
        assert_equal "pve1", result.volume.node
      end
    end
  end
end
