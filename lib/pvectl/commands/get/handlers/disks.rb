# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing physical disks on Proxmox nodes.
        #
        # Implements ResourceHandler interface for the "disks" resource type.
        # Uses Repositories::Disk for data access and Presenters::Disk for formatting.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("disks")
        #   disks = handler.list(node: "pve1")
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Disk Disk repository
        # @see Pvectl::Presenters::Disk Disk presenter
        #
        class Disks
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Disk, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists physical disks with optional filtering.
          #
          # @param node [String, nil] filter by node name
          # @param name [String, nil] filter by device path (e.g., "/dev/sda")
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility
          # @return [Array<Models::PhysicalDisk>] collection of PhysicalDisk models
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            disks = repository.list(node: node)
            disks = disks.select { |d| d.devpath == name } if name
            disks
          end

          # Describes a single physical disk with SMART data.
          #
          # Locates the disk by devpath across all nodes (or a specific node),
          # then fetches SMART data and merges it into the model.
          #
          # @param name [String] device path (e.g., "/dev/nvme0n1")
          # @param node [String, nil] optional node filter
          # @param args [Array<String>] unused, for interface compatibility
          # @param vmid [String, nil] unused, for interface compatibility
          # @return [Models::PhysicalDisk] enriched disk model
          # @raise [Pvectl::ResourceNotFoundError] when disk not found
          def describe(name:, node: nil, args: [], vmid: nil)
            disks = repository.list(node: node)
            disk = disks.find { |d| d.devpath == name }
            raise Pvectl::ResourceNotFoundError, "Disk not found: #{name}" unless disk

            smart_data = repository.smart(disk.node, name)
            disk.merge_smart(smart_data)
            disk
          end

          # Returns presenter for physical disks.
          #
          # @return [Presenters::Disk] Disk presenter instance
          def presenter
            Pvectl::Presenters::Disk.new
          end

          # Returns selector class for client-side filtering.
          #
          # @return [Class] Selectors::Disk class
          def selector_class
            Pvectl::Selectors::Disk
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Disk] Disk repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Disk] configured Disk repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Disk.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "disks",
  Pvectl::Commands::Get::Handlers::Disks,
  aliases: ["disk"]
)
