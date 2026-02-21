# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing and describing snapshots.
        #
        # Uses --vmid flag (repeatable) for VM/CT filtering and --node for node filtering.
        # Without --vmid, operates cluster-wide.
        #
        # @example List snapshots for specific VMs
        #   handler.list(args: [], vmid: ["100", "101"])
        #
        # @example List all snapshots cluster-wide
        #   handler.list(args: [])
        #
        class Snapshots
          include ResourceHandler

          def initialize(service: nil)
            @service = service
          end

          # Lists snapshots, optionally filtered by VMIDs and/or node.
          #
          # @param vmid [Array<String>, nil] VM/CT IDs from --vmid flag
          # @param node [String, nil] node name from --node flag
          # @param args [Array<String>] unused positional args
          # @return [Array<Models::Snapshot>] collection of snapshot models
          def list(node: nil, name: nil, args: [], storage: nil, vmid: nil, **_options)
            parsed_vmids = parse_vmids(vmid)
            service.list(parsed_vmids, node: node)
          end

          # Describes a snapshot by name.
          #
          # @param name [String] snapshot name to find
          # @param vmid [Array<String>, nil] VM/CT IDs from --vmid flag
          # @param node [String, nil] node name from --node flag
          # @param args [Array<String>] unused positional args
          # @return [Models::SnapshotDescription] snapshot description
          def describe(name:, node: nil, args: [], vmid: nil, **_options)
            parsed_vmids = parse_vmids(vmid)
            service.describe(parsed_vmids, name, node: node)
          end

          # Returns presenter for snapshots.
          #
          # @return [Presenters::Snapshot] snapshot presenter instance
          def presenter
            Pvectl::Presenters::Snapshot.new
          end

          private

          # Parses --vmid flag values to integer array.
          #
          # @param vmid [Array<String>, String, nil] raw vmid values
          # @return [Array<Integer>] parsed VMIDs (empty array if nil)
          def parse_vmids(vmid)
            return [] if vmid.nil?

            Array(vmid).map(&:to_i)
          end

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
