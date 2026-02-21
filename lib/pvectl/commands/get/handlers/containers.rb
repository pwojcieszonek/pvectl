# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing LXC containers.
        #
        # Implements ResourceHandler interface for the "containers" resource type.
        # Uses Repositories::Container for data access and Presenters::Container for formatting.
        #
        # Registered with ResourceRegistry on file load for "containers", "container", "ct", and "cts".
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("containers")
        #   containers = handler.list(node: "pve1")
        #   presenter = handler.presenter
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Container Container repository
        # @see Pvectl::Presenters::Container Container presenter
        #
        class Containers
          include ResourceHandler

          # CTID validation pattern (100-999999999)
          CTID_PATTERN = /\A[1-9]\d{2,8}\z/

          # Sort field mappings.
          # Negative values for descending sort (higher values first).
          SORT_FIELDS = {
            "name" => ->(c) { c.name || "" },
            "node" => ->(c) { c.node || "" },
            "cpu" => ->(c) { -(c.cpu || 0) },
            "memory" => ->(c) { -(c.mem || 0) },
            "disk" => ->(c) { -(c.disk || 0) },
            "netin" => ->(c) { -(c.netin || 0) },
            "netout" => ->(c) { -(c.netout || 0) }
          }.freeze

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Container, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Returns selector class for container filtering.
          #
          # @return [Class] Selectors::Container
          def selector_class
            Pvectl::Selectors::Container
          end

          # Lists containers with optional filtering and sorting.
          #
          # @param node [String, nil] filter by node name
          # @param name [String, nil] filter by container name
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility
          # @param sort [String, nil] sort field (name, node, cpu, memory, disk, netin, netout)
          # @return [Array<Models::Container>] collection of Container models
          def list(node: nil, name: nil, args: [], storage: nil, sort: nil, **_options)
            containers = repository.list(node: node)
            containers = containers.select { |c| c.name == name } if name
            containers = apply_sort(containers, sort) if sort
            containers
          end

          # Returns presenter for containers.
          #
          # @return [Presenters::Container] Container presenter instance
          def presenter
            Pvectl::Presenters::Container.new
          end

          # Describes a single container with comprehensive details.
          #
          # @param name [String] CTID as string (consistent with handler interface)
          # @param node [String, nil] unused, for API consistency
          # @return [Models::Container] Container model with full details
          # @raise [ArgumentError] if CTID format is invalid
          # @raise [Pvectl::ResourceNotFoundError] if container not found
          def describe(name:, node: nil, args: [], vmid: nil)
            raise ArgumentError, "Invalid CTID: must be positive integer (100-999999999)" unless valid_ctid?(name)

            ctid = name.to_i
            container = repository.describe(ctid)
            raise Pvectl::ResourceNotFoundError, "Container not found: #{ctid}" if container.nil?

            container
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Container] Container repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Container] configured Container repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Container.new(connection)
          end

          # Applies sorting to containers collection.
          #
          # @param containers [Array<Models::Container>] containers to sort
          # @param sort_field [String] field to sort by
          # @return [Array<Models::Container>] sorted containers
          def apply_sort(containers, sort_field)
            sort_proc = SORT_FIELDS[sort_field.to_s]
            return containers unless sort_proc

            containers.sort_by(&sort_proc)
          end

          # Validates CTID format.
          #
          # CTID must be a positive integer between 100 and 999999999.
          # The minimum CTID in Proxmox is 100 (unlike VMID which can be 1).
          #
          # @param ctid [String, nil] CTID to validate
          # @return [Boolean] true if valid
          def valid_ctid?(ctid)
            return false if ctid.nil? || ctid.to_s.empty?

            ctid.to_s.match?(CTID_PATTERN)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "containers",
  Pvectl::Commands::Get::Handlers::Containers,
  aliases: ["container", "ct", "cts"]
)
