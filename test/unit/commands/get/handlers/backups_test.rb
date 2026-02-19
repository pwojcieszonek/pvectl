# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    module Get
      module Handlers
        class BackupsTest < Minitest::Test
          # ---------------------------
          # Standard interface tests
          # ---------------------------

          def test_list_without_vmid_returns_all_backups
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            result = handler.list(args: [])

            assert_equal [], result
            assert_nil mock_service.last_vmid
            assert_nil mock_service.last_storage
          end

          def test_list_with_vmid_filters_backups
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(args: ["100"])

            assert_equal 100, mock_service.last_vmid
            assert_nil mock_service.last_storage
          end

          def test_list_with_storage_filter
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(args: [], storage: "local")

            assert_nil mock_service.last_vmid
            assert_equal "local", mock_service.last_storage
          end

          def test_list_with_vmid_and_storage_filter
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(args: ["100"], storage: "local")

            assert_equal 100, mock_service.last_vmid
            assert_equal "local", mock_service.last_storage
          end

          def test_list_ignores_node_and_name_parameters
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(node: "pve1", name: "ignored", args: ["100"])

            assert_equal 100, mock_service.last_vmid
            # node and name should be ignored
          end

          def test_list_accepts_standard_handler_interface
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            result = handler.list(node: nil, name: nil, args: [])

            assert_equal [], result
          end

          def test_list_with_zero_vmid_treats_as_nil
            # VMID "0" should be treated as nil (no filter)
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(args: ["0"])

            assert_nil mock_service.last_vmid
          end

          def test_list_accepts_storage_parameter
            mock_service = MockBackupService.new
            handler = Backups.new(service: mock_service)

            handler.list(node: nil, name: nil, args: [], storage: "backup-storage")

            assert_equal "backup-storage", mock_service.last_storage
          end

          # ---------------------------
          # Presenter tests
          # ---------------------------

          def test_presenter_returns_backup_presenter
            handler = Backups.new(service: nil)

            presenter = handler.presenter

            assert_instance_of Pvectl::Presenters::Backup, presenter
          end

          # ---------------------------
          # Module inclusion tests
          # ---------------------------

          def test_includes_resource_handler
            assert Backups.include?(ResourceHandler)
          end

          private

          # Mock service for testing
          class MockBackupService
            attr_reader :last_vmid, :last_storage

            def initialize
              @last_vmid = nil
              @last_storage = nil
            end

            def list(vmid: nil, storage: nil)
              @last_vmid = vmid
              @last_storage = storage
              []
            end
          end
        end
      end
    end
  end
end
