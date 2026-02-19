# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing Proxmox cluster storage pools.
        #
        # Implements ResourceHandler interface for the "storage" resource type.
        # Uses Repositories::Storage for data access and Presenters::Storage for formatting.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("storage")
        #   storage_pools = handler.list(node: "pve1")
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Storage Storage repository
        # @see Pvectl::Presenters::Storage Storage presenter
        #
        class Storage
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Storage, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists storage pools with optional filtering.
          #
          # @param node [String, nil] filter by node name
          # @param name [String, nil] filter by storage name
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility (storage is filtered via name)
          # @return [Array<Models::Storage>] collection of Storage models
          def list(node: nil, name: nil, args: [], storage: nil)
            storage_pools = repository.list(node: node)
            storage_pools = storage_pools.select { |s| s.name == name } if name
            storage_pools
          end

          # Returns presenter for storage pools.
          #
          # @return [Presenters::Storage] Storage presenter instance
          def presenter
            Pvectl::Presenters::Storage.new
          end

          # Describes a single storage pool by name.
          #
          # For local storage (exists on multiple nodes):
          # - Without node: returns array of instances (which nodes have it)
          # - With node: returns full describe for that specific node
          #
          # For shared storage: returns full describe (single instance).
          #
          # @param name [String] storage name
          # @param node [String, nil] filter by node name (required for local storage)
          # @return [Models::Storage, Array<Models::Storage>] Storage model or array of instances
          # @raise [ArgumentError] if storage name is invalid
          # @raise [Pvectl::ResourceNotFoundError] if storage not found
          def describe(name:, node: nil)
            raise ArgumentError, "Invalid storage name" if name.nil? || name.empty?

            # Check if storage exists on multiple nodes (local storage)
            instances = repository.list_instances(name)
            raise Pvectl::ResourceNotFoundError, "Storage not found: #{name}" if instances.empty?

            if instances.size > 1 && node.nil?
              # Return list of instances instead of single describe
              return instances
            end

            # Single instance or node specified - full describe
            storage = repository.describe(name, node: node)
            unless storage
              if node
                raise Pvectl::ResourceNotFoundError, "Storage '#{name}' not found on node '#{node}'"
              else
                raise Pvectl::ResourceNotFoundError, "Storage not found: #{name}"
              end
            end

            storage
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Storage] Storage repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Storage] configured Storage repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Storage.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "storage",
  Pvectl::Commands::Get::Handlers::Storage,
  aliases: ["stor"]
)
