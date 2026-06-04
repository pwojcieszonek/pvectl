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

          # Describes one or more containers matching the given identifier (CTID or name).
          #
          # Resolves the identifier via the repository's +resolve_identifier+ method,
          # which matches by CTID (numeric string) or by container name. Returns a single
          # model when exactly one match is found, or a +DescribeCollection+ when
          # several containers share the same name.
          #
          # @param name [String] CTID or container name
          # @param node [String, nil] unused, for API consistency
          # @param args [Array<String>] unused, for interface compatibility
          # @param vmid [Integer, nil] unused, for interface compatibility
          # @return [Models::Container] single container model, or
          # @return [Models::DescribeCollection] collection of container models when multiple matched
          # @raise [Pvectl::ResourceNotFoundError] if no container matches the identifier
          def describe(name:, node: nil, args: [], vmid: nil)
            matches = repository.resolve_identifier(name)
            raise Pvectl::ResourceNotFoundError, "Container not found: #{name}" if matches.empty?

            models = matches.map { |m| repository.describe(m.vmid) }.compact
            raise Pvectl::ResourceNotFoundError, "Container not found: #{name}" if models.empty?

            models.size == 1 ? models.first : Pvectl::Models::DescribeCollection.new(models)
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
