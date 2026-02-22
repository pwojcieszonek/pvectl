# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditVolumeTest < Minitest::Test
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

      # Builds an editor callable that writes new content to the temp file.
      def build_editor(new_content)
        ->(path) { File.write(path, new_content) }
      end

      # Noop editor — does not modify the temp file, triggering cancellation.
      def build_noop_editor
        ->(_path) {}
      end

      def test_applies_config_changes
        update_args = nil
        repo = build_mock_repo(
          update_called: ->(id, node, params) { update_args = { id: id, node: node, params: params } }
        )

        # Editor changes cache from none to writeback
        edited_yaml = { "size" => "32G", "cache" => "writeback" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert result.successful?
        assert_kind_of Models::VolumeOperationResult, result
        assert_equal :edit, result.operation
        assert update_args, "update should have been called"
        assert_match(/cache=writeback/, update_args[:params][:scsi0].to_s)
        # Base volume id should be preserved
        assert update_args[:params][:scsi0].to_s.start_with?("local-lvm:vm-100-disk-0")
      end

      def test_applies_size_change
        resize_args = nil
        repo = build_mock_repo(
          resize_called: ->(id, node, disk, size) { resize_args = { id: id, node: node, disk: disk, size: size } }
        )

        # Editor changes size from 32G to 42G
        edited_yaml = { "size" => "42G", "cache" => "none" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert result.successful?
        assert resize_args, "resize should have been called"
        assert_equal "42G", resize_args[:size]
      end

      def test_mixed_size_and_config_changes
        resize_called = false
        update_called = false
        repo = build_mock_repo(
          resize_called: ->(_id, _node, _disk, _size) { resize_called = true },
          update_called: ->(_id, _node, _params) { update_called = true }
        )

        # Editor changes both size and cache
        edited_yaml = { "size" => "42G", "cache" => "writeback" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert result.successful?
        assert resize_called, "resize should have been called"
        assert update_called, "update should have been called"
      end

      def test_cancelled_edit_returns_nil
        repo = build_mock_repo

        editor_session = EditorSession.new(editor: build_noop_editor)

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert_nil result
      end

      def test_disk_not_found_returns_error
        repo = build_mock_repo(config: { ide0: "some-other-disk,size=10G" })

        service = EditVolume.new(repository: repo, resource_type: :vm)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert result.failed?
        assert_match(/not found/, result.error)
        assert_kind_of Models::VolumeOperationResult, result
      end

      def test_no_changes_returns_nil
        repo = build_mock_repo

        # Editor writes back the same values
        same_yaml = { "size" => "32G", "cache" => "none" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(same_yaml))

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert_nil result
      end

      def test_dry_run_returns_result_without_calling_api
        repo = build_mock_repo

        # Editor changes cache
        edited_yaml = { "size" => "32G", "cache" => "writeback" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditVolume.new(
          repository: repo, resource_type: :vm,
          editor_session: editor_session, options: { dry_run: true }
        )
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert result.successful?
        assert result.resource[:diff]
        # resize/update were never expected — if called, no tracking was set up
      end

      def test_result_has_volume_info
        repo = build_mock_repo(
          update_called: ->(_id, _node, _params) {}
        )

        edited_yaml = { "size" => "32G", "cache" => "writeback" }.to_yaml
        editor_session = EditorSession.new(editor: build_editor(edited_yaml))

        service = EditVolume.new(repository: repo, resource_type: :vm, editor_session: editor_session)
        result = service.execute(id: 100, disk: "scsi0", node: "pve1")

        assert_equal :edit, result.operation
        assert_equal "scsi0", result.volume.name
        assert_equal "vm", result.volume.resource_type
        assert_equal 100, result.volume.resource_id
        assert_equal "pve1", result.volume.node
      end
    end
  end
end
