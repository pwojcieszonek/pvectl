# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Repositories
    class BackupTest < Minitest::Test
      # --- list tests ---

      def test_list_returns_backups_from_single_node_and_storage
        api_response = [
          {
            volid: "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst",
            size: 1_610_612_736,
            ctime: 1705315800,
            format: "vma",
            notes: "Pre-upgrade",
            protected: 1,
            vmid: 100
          },
          {
            volid: "local:backup/vzdump-lxc-101-2024_01_15-11_00_00.tar.zst",
            size: 536_870_912,
            ctime: 1705317600,
            format: "tar",
            vmid: 101
          }
        ]

        repository = create_repo_for_list(
          node: "pve1",
          storage: "local",
          content_response: api_response
        )

        backups = repository.list(node: "pve1", storage: "local")

        assert_equal 2, backups.length
        assert_instance_of Models::Backup, backups[0]
        assert_equal "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst", backups[0].volid
        assert_equal 100, backups[0].vmid
        assert_equal "pve1", backups[0].node
        assert_equal "local", backups[0].storage
        assert_equal 1_610_612_736, backups[0].size
        assert_equal "Pre-upgrade", backups[0].notes
        assert backups[0].protected?

        assert_equal 101, backups[1].vmid
        refute backups[1].protected?
      end

      def test_list_filters_by_vmid
        api_response = [
          { volid: "local:backup/vzdump-qemu-100-xxx.vma.zst", vmid: 100, ctime: 1705315800 },
          { volid: "local:backup/vzdump-qemu-200-xxx.vma.zst", vmid: 200, ctime: 1705315900 }
        ]

        repository = create_repo_for_list(
          node: "pve1",
          storage: "local",
          content_response: api_response
        )

        backups = repository.list(node: "pve1", storage: "local", vmid: 100)

        assert_equal 1, backups.length
        assert_equal 100, backups[0].vmid
      end

      def test_list_discovers_all_nodes_when_node_not_specified
        repository = create_repo_for_discovery(
          nodes: [{ node: "pve1" }, { node: "pve2" }],
          storages_by_node: {
            "pve1" => [{ storage: "local", content: "images,backup" }],
            "pve2" => [{ storage: "nas", content: "backup" }]
          },
          backups_by_node_storage: {
            ["pve1", "local"] => [{ volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, ctime: 1 }],
            ["pve2", "nas"] => [{ volid: "nas:backup/vzdump-qemu-200.vma.zst", vmid: 200, ctime: 2 }]
          }
        )

        backups = repository.list

        assert_equal 2, backups.length
        assert_equal 100, backups[0].vmid
        assert_equal "pve1", backups[0].node
        assert_equal 200, backups[1].vmid
        assert_equal "pve2", backups[1].node
      end

      def test_list_only_discovers_storages_with_backup_content
        repository = create_repo_for_discovery(
          nodes: [{ node: "pve1" }],
          storages_by_node: {
            "pve1" => [
              { storage: "local-lvm", content: "images,rootdir" },
              { storage: "local", content: "backup,iso" }
            ]
          },
          backups_by_node_storage: {
            ["pve1", "local"] => [{ volid: "local:backup/vzdump-qemu-100.vma.zst", vmid: 100, ctime: 1 }]
          }
        )

        backups = repository.list

        # Should only have backup from "local" storage (not local-lvm)
        assert_equal 1, backups.length
        assert_equal "local", backups[0].storage
      end

      # --- create tests ---

      def test_create_backup_with_defaults
        repository, captured_params = create_repo_for_create("pve1")

        upid = repository.create(100, "pve1", storage: "local")

        assert_equal "UPID:pve1:00001234:vzdump", upid
        assert_equal 100, captured_params[:vmid]
        assert_equal "local", captured_params[:storage]
        assert_equal "snapshot", captured_params[:mode]
        assert_equal "zstd", captured_params[:compress]
        refute captured_params.key?(:notes)
        refute captured_params.key?(:protected)
      end

      def test_create_backup_with_all_options
        repository, captured_params = create_repo_for_create("pve1")

        upid = repository.create(
          100, "pve1",
          storage: "nas",
          mode: "stop",
          compress: "gzip",
          notes: "Important backup",
          protected: true
        )

        assert_equal "UPID:pve1:00001234:vzdump", upid
        assert_equal 100, captured_params[:vmid]
        assert_equal "nas", captured_params[:storage]
        assert_equal "stop", captured_params[:mode]
        assert_equal "gzip", captured_params[:compress]
        assert_equal "Important backup", captured_params[:notes]
        assert_equal 1, captured_params[:protected]
      end

      # --- delete tests ---

      def test_delete_backup
        volid = "local:backup/vzdump-qemu-100-2024_01_15-10_30_00.vma.zst"
        encoded_volid = "local%3Abackup%2Fvzdump-qemu-100-2024_01_15-10_30_00.vma.zst"

        captured_path = nil
        repository = create_repo_for_delete("pve1") { |path| captured_path = path }

        upid = repository.delete(volid, "pve1")

        assert_equal "UPID:pve1:00001235:delete", upid
        assert_equal "nodes/pve1/storage/local/content/#{encoded_volid}", captured_path
      end

      # --- restore tests ---

      def test_restore_qemu_backup
        repository, captured = create_repo_for_restore("pve1")

        upid = repository.restore(
          "local:backup/vzdump-qemu-100-xxx.vma.zst",
          "pve1",
          vmid: 100
        )

        assert_equal "UPID:pve1:00001236:restore", upid
        assert_equal "nodes/pve1/qemu", captured[:endpoint]
        assert_equal "local:backup/vzdump-qemu-100-xxx.vma.zst", captured[:params][:archive]
        assert_equal 100, captured[:params][:vmid]
      end

      def test_restore_lxc_backup
        repository, captured = create_repo_for_restore("pve1")

        upid = repository.restore(
          "local:backup/vzdump-lxc-101-xxx.tar.zst",
          "pve1",
          vmid: 101
        )

        assert_equal "UPID:pve1:00001236:restore", upid
        assert_equal "nodes/pve1/lxc", captured[:endpoint]
        assert_equal "local:backup/vzdump-lxc-101-xxx.tar.zst", captured[:params][:archive]
        assert_equal 101, captured[:params][:vmid]
      end

      def test_restore_with_all_options
        repository, captured = create_repo_for_restore("pve1")

        upid = repository.restore(
          "local:backup/vzdump-qemu-100-xxx.vma.zst",
          "pve1",
          vmid: 200,
          storage: "local-lvm",
          force: true,
          start: true,
          unique: true
        )

        assert_equal "UPID:pve1:00001236:restore", upid
        assert_equal 200, captured[:params][:vmid]
        assert_equal "local-lvm", captured[:params][:storage]
        assert_equal 1, captured[:params][:force]
        assert_equal 1, captured[:params][:start]
        assert_equal 1, captured[:params][:unique]
      end

      private

      # Creates a repository configured for list tests with single node/storage
      def create_repo_for_list(node:, storage:, content_response:)
        mock_resource = Object.new
        mock_resource.define_singleton_method(:get) do |**_kwargs|
          content_response
        end

        mock_client = Object.new
        expected_path = "nodes/#{node}/storage/#{storage}/content"
        mock_client.define_singleton_method(:[]) do |path|
          raise "Unexpected path: #{path}" unless path == expected_path

          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        Backup.new(mock_connection)
      end

      # Creates a repository configured for discovery tests (no node/storage specified)
      def create_repo_for_discovery(nodes:, storages_by_node:, backups_by_node_storage:)
        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          resource = Object.new

          case path
          when "nodes"
            resource.define_singleton_method(:get) { nodes }
          when %r{^nodes/([^/]+)/storage$}
            node_name = ::Regexp.last_match(1)
            resource.define_singleton_method(:get) { storages_by_node[node_name] || [] }
          when %r{^nodes/([^/]+)/storage/([^/]+)/content$}
            node_name = ::Regexp.last_match(1)
            storage_name = ::Regexp.last_match(2)
            backups = backups_by_node_storage[[node_name, storage_name]] || []
            resource.define_singleton_method(:get) { |**_kwargs| backups }
          else
            raise "Unexpected path: #{path}"
          end

          resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        Backup.new(mock_connection)
      end

      # Creates a repository configured for create tests, returns captured params
      def create_repo_for_create(node)
        captured_params = {}

        mock_resource = Object.new
        mock_resource.define_singleton_method(:post) do |params|
          captured_params.merge!(params)
          "UPID:#{node}:00001234:vzdump"
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          raise "Expected vzdump path" unless path == "nodes/#{node}/vzdump"

          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        [Backup.new(mock_connection), captured_params]
      end

      # Creates a repository configured for delete tests
      def create_repo_for_delete(node, &block)
        mock_resource = Object.new
        mock_resource.define_singleton_method(:delete) do
          "UPID:#{node}:00001235:delete"
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          block.call(path) if block
          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        Backup.new(mock_connection)
      end

      # Creates a repository configured for restore tests
      def create_repo_for_restore(node)
        captured = { endpoint: nil, params: nil }

        mock_resource = Object.new
        mock_resource.define_singleton_method(:post) do |params|
          captured[:params] = params
          "UPID:#{node}:00001236:restore"
        end

        mock_client = Object.new
        mock_client.define_singleton_method(:[]) do |path|
          captured[:endpoint] = path
          mock_resource
        end

        mock_connection = Object.new
        mock_connection.define_singleton_method(:client) { mock_client }

        [Backup.new(mock_connection), captured]
      end
    end
  end
end
