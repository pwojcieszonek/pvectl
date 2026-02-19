# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Services
    class EditContainerTest < Minitest::Test
      describe "#execute" do
        # --- Helpers ---

        def build_container(attrs = {})
          defaults = { vmid: 200, name: "web-ct", status: "running", node: "pve1" }
          Models::Container.new(defaults.merge(attrs))
        end

        def build_config(extras = {})
          { hostname: "web-ct", cores: 2, memory: 2048, digest: "def456" }.merge(extras)
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
            ct_repo = Minitest::Mock.new
            config = build_config
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 2", "cores: 4")

            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            ct_repo.expect(:update, nil) do |ctid, node, params|
              update_params = params
              true
            end

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert result.successful?
            assert_equal 4, update_params[:cores]
            assert_equal "def456", update_params[:digest]
            ct_repo.verify
          end
        end

        # --- Returns nil when cancelled ---

        describe "cancelled" do
          it "returns nil when editor content is unchanged" do
            ct_repo = Minitest::Mock.new
            config = build_config
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            editor = build_noop_editor
            session = EditorSession.new(editor: editor)

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert_nil result
          end
        end

        # --- Not found ---

        describe "not found" do
          it "returns error when container not found" do
            ct_repo = Minitest::Mock.new
            ct_repo.expect(:get, nil, [200])

            service = EditContainer.new(container_repository: ct_repo)
            result = service.execute(ctid: 200)

            assert result.failed?
            assert_match(/Container 200 not found/, result.error)
          end
        end

        # --- API failure ---

        describe "API failure" do
          it "returns error on API failure" do
            ct_repo = Minitest::Mock.new
            config = build_config
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 2", "cores: 4")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            ct_repo.expect(:update, nil) do |_ctid, _node, _params|
              raise StandardError, "API timeout"
            end

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert result.failed?
            assert_equal "API timeout", result.error
          end
        end

        # --- Dry run ---

        describe "dry run" do
          it "does not call update in dry run mode" do
            ct_repo = Minitest::Mock.new
            config = build_config
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 2", "cores: 4")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            service = EditContainer.new(container_repository: ct_repo, editor_session: session,
                                        options: { dry_run: true })
            result = service.execute(ctid: 200)

            assert result.successful?
            ct_repo.verify
          end
        end

        # --- Optimistic locking ---

        describe "optimistic locking" do
          it "sends digest for optimistic locking" do
            ct_repo = Minitest::Mock.new
            config = build_config(digest: "cafebabe")
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 2", "cores: 4")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            ct_repo.expect(:update, nil) do |_ctid, _node, params|
              update_params = params
              true
            end

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            service.execute(ctid: 200)

            assert_equal "cafebabe", update_params[:digest]
          end
        end

        # --- Removed keys ---

        describe "removed keys" do
          it "handles removed keys with delete param" do
            ct_repo = Minitest::Mock.new
            config = build_config(description: "old desc")
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.lines.reject { |l| l.include?("description:") }.join
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            update_params = nil
            ct_repo.expect(:update, nil) do |_ctid, _node, params|
              update_params = params
              true
            end

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert result.successful?
            assert_includes update_params[:delete], "description"
          end
        end

        # --- Read-only violations ---

        describe "read-only violations" do
          it "detects read-only field changes" do
            ct_repo = Minitest::Mock.new
            config = build_config(vmid: 200)
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("vmid: 200", "vmid: 999")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert result.failed?
            assert_match(/read-only/i, result.error)
            assert_match(/vmid/, result.error)
          end
        end

        # --- Result model type ---

        describe "result model" do
          it "returns ContainerOperationResult with edit operation" do
            ct_repo = Minitest::Mock.new
            config = build_config
            ct = build_container

            ct_repo.expect(:get, ct, [200])
            ct_repo.expect(:fetch_config, config, ["pve1", 200])

            original_yaml = ConfigSerializer.to_yaml(config, type: :container,
                                                     resource: { vmid: 200, node: "pve1", status: "running" })
            edited_yaml = original_yaml.gsub("cores: 2", "cores: 4")
            editor = build_editor(edited_yaml)
            session = EditorSession.new(editor: editor)

            ct_repo.expect(:update, nil) do |_ctid, _node, _params|
              true
            end

            service = EditContainer.new(container_repository: ct_repo, editor_session: session)
            result = service.execute(ctid: 200)

            assert_instance_of Models::ContainerOperationResult, result
            assert_equal :edit, result.operation
            assert_instance_of Models::Container, result.container
            assert_equal 200, result.container.vmid
          end
        end
      end
    end
  end
end
