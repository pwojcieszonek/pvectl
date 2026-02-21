# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing and describing snapshots.
        #
        # VMIDs can be passed via args to scope the operation.
        # When args is empty, operates on all cluster resources.
        # The node: and name: parameters are ignored.
        #
        # @example Usage
        #   handler.list(node: nil, name: nil, args: ["100", "101"])
        #   handler.list(node: nil, name: nil, args: [])  # all cluster snapshots
        #
        class Snapshots
          include ResourceHandler

          VMID_PATTERN = /\A[1-9]\d{0,8}\z/

          def initialize(service: nil)
            @service = service
          end

          # Lists snapshots for given VMIDs, or all cluster snapshots when args is empty.
          #
          # Conforms to the standard ResourceHandler interface but uses args for VMIDs.
          # The node: and name: parameters are ignored for snapshots.
          #
          # @param node [String, nil] ignored for snapshots
          # @param name [String, nil] ignored for snapshots
          # @param args [Array<String>] VM/container IDs as strings (empty = all cluster)
          # @param storage [String, nil] unused, for interface compatibility
          # @return [Array<Models::Snapshot>] collection of snapshot models
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            parsed_vmids = args.map(&:to_i)
            service.list(parsed_vmids)
          end

          # Describes a snapshot by name.
          #
          # Finds the named snapshot across given VMIDs (or all VMs if args is empty).
          # Returns a SnapshotDescription with target + siblings for tree building.
          #
          # @param name [String] snapshot name to find
          # @param node [String, nil] unused for snapshots
          # @param args [Array<String>] VM/container IDs as strings (empty = search all)
          # @return [Models::SnapshotDescription] snapshot description
          # @raise [ResourceNotFoundError] if snapshot not found
          def describe(name:, node: nil, args: [])
            parsed_vmids = args.map(&:to_i)
            service.describe(parsed_vmids, name)
          end

          # Returns presenter for snapshots.
          #
          # @return [Presenters::Snapshot] snapshot presenter instance
          def presenter
            Pvectl::Presenters::Snapshot.new
          end

          private

          def service
            @service ||= build_service
          end

          def build_service
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)

            snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
            resolver = Pvectl::Utils::ResourceResolver.new(connection)
            task_repo = Pvectl::Repositories::Task.new(connection)

            Pvectl::Services::Snapshot.new(
              snapshot_repo: snapshot_repo,
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
  "snapshots",
  Pvectl::Commands::Get::Handlers::Snapshots,
  aliases: ["snapshot", "snap"]
)
