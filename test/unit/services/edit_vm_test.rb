# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditVmTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_vm(attrs = {})
          defaults = { vmid: 100, name: "web", status: "running", node: "pve1" }
          Models::Vm.new(defaults.merge(attrs))
        end

        def build_config(extras = {})
          { name: "web", cores: 4, memory: 8192, digest: "abc123" }.merge(extras)
        end

        def build_editor(new_content)
          ->(path) { File.write(path, new_content) }
        end

        def build_noop_editor
          ->(_path) {}
        end

        # --- Applies changes ---

        describe "applies changes" do
          it "applies changes to API" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            # Build the YAML that the editor will "produce" with cores changed to 8
            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 4", "cores: 8")

            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            vm_repo.expect(:update, nil) do |vmid, node, params|
              update_params = params
              true
            end

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert result.successful?
            assert_equal 8, update_params[:cores]
            assert_equal "abc123", update_params[:digest]
            vm_repo.verify
          end
        end

        # --- Returns nil when cancelled ---

        describe "cancelled" do
          it "returns nil when editor content is unchanged" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            # Editor does not change file content (noop)
            editor = build_noop_editor
            session = EditorSession.new(editor: editor)

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert_nil result
          end
        end

        # --- Not found ---

        describe "not found" do
          it "returns error when VM not found" do
            vm_repo = Minitest::Mock.new
            vm_repo.expect(:get, nil, [100])

            service = EditVm.new(vm_repository: vm_repo)
            result = service.execute(vmid: 100)

            assert result.failed?
            assert_match(/VM 100 not found/, result.error)
          end
        end

        # --- API failure ---

        describe "API failure" do
          it "returns error on API failure" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 4", "cores: 8")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            vm_repo.expect(:update, nil) do |_vmid, _node, _params|
              raise StandardError, "API connection refused"
            end

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert result.failed?
            assert_equal "API connection refused", result.error
          end
        end

        # --- Dry run ---

        describe "dry run" do
          it "does not call update in dry run mode" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 4", "cores: 8")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            service = EditVm.new(vm_repository: vm_repo, editor_session: session,
                                 options: { dry_run: true })
            result = service.execute(vmid: 100)

            assert result.successful?
            # update was never expected, so if it was called mock would raise
            vm_repo.verify
          end
        end

        # --- Optimistic locking ---

        describe "optimistic locking" do
          it "sends digest for optimistic locking" do
            vm_repo = Minitest::Mock.new
            config = build_config(digest: "deadbeef")
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 4", "cores: 8")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            vm_repo.expect(:update, nil) do |_vmid, _node, params|
              update_params = params
              true
            end

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            service.execute(vmid: 100)

            assert_equal "deadbeef", update_params[:digest]
          end
        end

        # --- Removed keys ---

        describe "removed keys" do
          it "handles removed keys with delete param" do
            vm_repo = Minitest::Mock.new
            config = build_config(description: "old desc")
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            # Remove the description line from the YAML
            edited_yaml = original_yaml.lines.reject { |l| l.include?("description:") }.join
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            vm_repo.expect(:update, nil) do |_vmid, _node, params|
              update_params = params
              true
            end

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert result.successful?
            assert_includes update_params[:delete], "description"
          end
        end

        # --- Read-only violations ---

        describe "read-only violations" do
          it "detects read-only field changes" do
            vm_repo = Minitest::Mock.new
            config = build_config(vmid: 100)
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            # Change vmid (read-only field)
            edited_yaml = original_yaml.gsub("vmid: 100", "vmid: 999")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert result.failed?
            assert_match(/read-only/i, result.error)
            assert_match(/vmid/, result.error)
          end
        end

        # --- No actual changes ---

        describe "no changes" do
          it "returns nil when no actual changes are made" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            # Editor adds a trailing newline but keeps same values — round-trip preserves
            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            # Re-add the same content with a minor whitespace difference that from_yaml normalizes away
            edited_yaml = "#{original_yaml}\n"
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            # EditorSession detects no change → nil, OR service detects no diff → nil
            assert_nil result
          end
        end

        # --- Result model type ---

        describe "result model" do
          it "returns VmOperationResult with edit operation" do
            vm_repo = Minitest::Mock.new
            config = build_config
            vm = build_vm

            vm_repo.expect(:get, vm, [100])
            vm_repo.expect(:fetch_config, config, ["pve1", 100])

            original_yaml = ConfigSerializer.to_yaml(config, type: :vm,
                                                     resource: { vmid: 100, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 4", "cores: 8")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            vm_repo.expect(:update, nil) do |_vmid, _node, _params|
              true
            end

            service = EditVm.new(vm_repository: vm_repo, editor_session: session)
            result = service.execute(vmid: 100)

            assert_instance_of Models::VmOperationResult, result
            assert_equal :edit, result.operation
            assert_instance_of Models::Vm, result.vm
            assert_equal 100, result.vm.vmid
          end
        end
      end
    end
  end
end
