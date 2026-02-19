# frozen_string_literal: true

require "test_helper"

module Pvectl
  # Integration smoke test for the full VM edit pipeline.
  #
  # Only the repository is mocked; ConfigSerializer and EditorSession are real.
  # This verifies the complete flow: repo.get -> fetch_config -> to_yaml ->
  # editor modifies file -> from_yaml -> diff -> repo.update with correct params.
  class EditVmIntegrationTest < Minitest::Test
    private

    def build_vm(attrs = {})
      defaults = { vmid: 100, name: "test-vm", status: "running", node: "pve1" }
      Models::Vm.new(defaults.merge(attrs))
    end

    def build_full_config(extras = {})
      {
        cores: 4, sockets: 1, memory: 8192,
        name: "test-vm", ostype: "l26",
        scsi0: "local-lvm:vm-100-disk-0,size=32G",
        net0: "virtio=AA:BB:CC:DD:EE:FF,bridge=vmbr0",
        digest: "abc123"
      }.merge(extras)
    end

    def build_mock_repo(vm:, config:, expect_update: true, &update_block)
      repo = Minitest::Mock.new
      repo.expect(:get, vm, [vm.vmid])
      repo.expect(:fetch_config, config, [vm.node, vm.vmid])
      repo.expect(:update, nil, &update_block) if expect_update
      repo
    end

    def build_gsub_editor(*replacements)
      ->(path) {
        content = File.read(path)
        replacements.each { |from, to| content = content.gsub(from, to) }
        File.write(path, content)
      }
    end

    public

    def test_applies_multiple_field_changes_through_full_pipeline
      config = build_full_config
      vm = build_vm

      editor = build_gsub_editor(["cores: 4", "cores: 8"], ["memory: 8192", "memory: 16384"])

      update_params = nil
      repo = build_mock_repo(vm: vm, config: config) do |vmid, node, params|
        update_params = params
        vmid == 100 && node == "pve1"
      end

      session = EditorSession.new(editor: editor)
      service = Services::EditVm.new(vm_repository: repo, editor_session: session)
      result = service.execute(vmid: 100)

      assert result.successful?
      assert_equal :edit, result.operation
      assert_instance_of Models::VmOperationResult, result

      # Verify correct values in update params
      assert_equal 8, update_params[:cores]
      assert_equal 16_384, update_params[:memory]
      assert_equal "abc123", update_params[:digest]

      # Verify only changed keys are sent (not all config keys)
      refute update_params.key?(:sockets)
      refute update_params.key?(:name)
      refute update_params.key?(:ostype)
      refute update_params.key?(:scsi0)
      refute update_params.key?(:net0)

      repo.verify
    end

    def test_handles_key_removal_with_delete_param
      config = build_full_config(description: "old description")
      vm = build_vm

      editor = ->(path) {
        content = File.read(path)
        content = content.lines.reject { |l| l.include?("description:") }.join
        File.write(path, content)
      }

      update_params = nil
      repo = build_mock_repo(vm: vm, config: config) do |vmid, node, params|
        update_params = params
        vmid == 100 && node == "pve1"
      end

      session = EditorSession.new(editor: editor)
      service = Services::EditVm.new(vm_repository: repo, editor_session: session)
      result = service.execute(vmid: 100)

      assert result.successful?
      assert_includes update_params[:delete], "description"
      assert_equal "abc123", update_params[:digest]
      refute update_params.key?(:description)

      repo.verify
    end

    def test_returns_nil_when_editor_does_not_change_content
      config = build_full_config
      vm = build_vm

      # Noop editor — does not modify the file
      editor = ->(_path) {}

      repo = build_mock_repo(vm: vm, config: config, expect_update: false)

      session = EditorSession.new(editor: editor)
      service = Services::EditVm.new(vm_repository: repo, editor_session: session)
      result = service.execute(vmid: 100)

      assert_nil result
    end

    def test_skips_api_call_in_dry_run_mode
      config = build_full_config
      vm = build_vm

      editor = build_gsub_editor(["cores: 4", "cores: 8"])

      # No :update expectation — if called, mock would raise
      repo = build_mock_repo(vm: vm, config: config, expect_update: false)

      session = EditorSession.new(editor: editor)
      service = Services::EditVm.new(
        vm_repository: repo, editor_session: session,
        options: { dry_run: true }
      )
      result = service.execute(vmid: 100)

      assert result.successful?
      assert_equal :edit, result.operation

      # Verify diff is present even in dry-run
      diff = result.resource[:diff]
      assert diff[:changed].key?(:cores)

      repo.verify
    end
  end
end
