# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing backups.
        #
        # Unlike Snapshots handler, Backups allows listing all backups
        # or filtering by optional VMID.
        #
        # @example Usage
        #   handler.list(node: nil, name: nil, args: [])        # all backups
        #   handler.list(node: nil, name: nil, args: ["100"])   # backups for VM 100
        #
        class Backups
          include ResourceHandler

          def initialize(service: nil)
            @service = service
          end

          # Lists backups with optional VMID filter.
          #
          # @param node [String, nil] ignored (backups can span nodes)
          # @param name [String, nil] ignored
          # @param args [Array<String>] optional VMID filter (first arg only)
          # @param storage [String, nil] filter by storage
          # @return [Array<Models::Backup>] collection of backup models
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            vmid = args.first&.to_i
            vmid = nil if vmid&.zero?

            service.list(vmid: vmid, storage: storage)
          end

          # Returns presenter for backups.
          #
          # @return [Presenters::Backup] backup presenter instance
          def presenter
            Pvectl::Presenters::Backup.new
          end

          private

          def service
            @service ||= build_service
          end

          def build_service
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)

            backup_repo = Pvectl::Repositories::Backup.new(connection)
            resolver = Pvectl::Utils::ResourceResolver.new(connection)
            task_repo = Pvectl::Repositories::Task.new(connection)

            Pvectl::Services::Backup.new(
              backup_repo: backup_repo,
              resource_resolver: resolver,
              task_repo: task_repo
            )
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "backups",
  Pvectl::Commands::Get::Handlers::Backups,
  aliases: ["backup"]
)
