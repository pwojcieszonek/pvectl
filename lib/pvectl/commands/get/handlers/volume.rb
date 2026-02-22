# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing and describing virtual disk volumes.
        #
        # Implements ResourceHandler interface for the "volumes" resource type.
        # Supports two listing modes:
        # - Config mode: list volumes from VM/CT config by resource type and IDs
        # - Storage mode: list volumes from a specific storage
        #
        # Uses Repositories::Volume for data access, Presenters::Volume for
        # formatting, and Selectors::Volume for client-side filtering.
        #
        # @example List VM volumes via ResourceRegistry
        #   handler = ResourceRegistry.for("volumes")
        #   volumes = handler.list(args: ["vm", "100"], node: "pve1")
        #
        # @example List storage volumes
        #   handler = ResourceRegistry.for("volumes")
        #   volumes = handler.list(storage: "local-lvm")
        #
        # @example Describe a specific volume
        #   handler = ResourceRegistry.for("volumes")
        #   volume = handler.describe(name: "vm", args: ["100", "scsi0"])
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Volume Volume repository
        # @see Pvectl::Presenters::Volume Volume presenter
        #
        class Volume
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Volume, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists virtual disk volumes with two modes of operation.
          #
          # Config mode: requires resource type and at least one ID in args.
          #   args = ["vm", "100", "101"] lists volumes from VMs 100 and 101.
          #
          # Storage mode: requires storage parameter.
          #   storage = "local-lvm" lists all volumes on that storage.
          #
          # @param args [Array<String>] resource type and IDs (config mode)
          # @param storage [String, nil] storage name (storage mode)
          # @param node [String, nil] filter by node name
          # @param _options [Hash] unused, for interface compatibility
          # @return [Array<Models::Volume>] collection of Volume models
          def list(args: [], storage: nil, node: nil, **_options)
            if storage
              repository.list_from_storage(storage: storage, node: node)
            elsif args.length >= 2
              resource_type = args[0]
              ids = args[1..].map(&:to_i)
              repository.list_from_config(resource_type: resource_type, ids: ids, node: node)
            else
              $stderr.puts "Usage: pvectl get volume <vm|ct> <ID...> [--node NODE]"
              $stderr.puts "       pvectl get volume --storage <STORAGE> [--node NODE]"
              []
            end
          end

          # Describes a single virtual disk volume.
          #
          # Locates a specific disk by resource type, ID, and disk name.
          #
          # @param name [String] resource type ("vm" or "ct")
          # @param args [Array<String>] [id, disk_name] pair
          # @param node [String, nil] optional node filter
          # @param _options [Hash] unused, for interface compatibility
          # @return [Models::Volume] found Volume model
          # @raise [Pvectl::ResourceNotFoundError] when volume not found
          def describe(name:, args: [], node: nil, **_options)
            resource_type = name
            id = args[0]&.to_i
            disk_name = args[1]

            volume = repository.find(resource_type: resource_type, id: id, disk_name: disk_name, node: node)
            raise Pvectl::ResourceNotFoundError, "Volume '#{disk_name}' not found on #{resource_type} #{id}" unless volume

            volume
          end

          # Returns presenter for virtual disk volumes.
          #
          # @return [Presenters::Volume] Volume presenter instance
          def presenter
            Pvectl::Presenters::Volume.new
          end

          # Returns selector class for client-side filtering.
          #
          # @return [Class] Selectors::Volume class
          def selector_class
            Pvectl::Selectors::Volume
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Volume] Volume repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Volume] configured Volume repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Volume.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "volumes",
  Pvectl::Commands::Get::Handlers::Volume,
  aliases: ["volume", "vol"]
)
