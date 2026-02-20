# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing Proxmox cluster nodes.
        #
        # Implements ResourceHandler interface for the "nodes" resource type.
        # Uses Repositories::Node for data access and Presenters::Node for formatting.
        #
        # Supports filtering by status and sorting by various fields.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("nodes")
        #   nodes = handler.list(filter: { status: "online" }, sort: "memory")
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::Node Node repository
        # @see Pvectl::Presenters::Node Node presenter
        #
        class Nodes
          include ResourceHandler

          # Sort field mappings.
          # Negative values for descending sort (higher values first).
          SORT_FIELDS = {
            "name" => ->(n) { n.name },
            "status" => ->(n) { n.status },
            "cpu" => ->(n) { -(n.cpu || 0) },
            "memory" => ->(n) { -(n.mem || 0) },
            "disk" => ->(n) { -(n.disk || 0) },
            "guests" => ->(n) { -n.guests_total },
            "uptime" => ->(n) { -(n.uptime || 0) }
          }.freeze

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Node, nil] repository (default: create new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists nodes with optional filtering and sorting.
          #
          # @param node [String, nil] not used for nodes (included for interface)
          # @param name [String, nil] filter by exact node name
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility
          # @param filter [Hash, nil] filter criteria (e.g., { status: "online" })
          # @param sort [String, nil] sort field (name, status, cpu, memory, disk, guests, uptime)
          # @param include_details [Boolean] fetch extended details (version, load), default true
          # @return [Array<Models::Node>] collection of Node models
          def list(node: nil, name: nil, args: [], storage: nil, filter: nil, sort: nil, include_details: true, **_options)
            nodes = repository.list(include_details: include_details)

            # Filter by name
            nodes = nodes.select { |n| n.name == name } if name

            # Apply filters
            nodes = apply_filters(nodes, filter) if filter

            # Apply sorting
            nodes = apply_sort(nodes, sort) if sort

            nodes
          end

          # Returns presenter for nodes.
          #
          # @return [Presenters::Node] Node presenter instance
          def presenter
            Pvectl::Presenters::Node.new
          end

          # Describes a single node with comprehensive details.
          #
          # @param name [String] node name
          # @param node [String, nil] unused, for API consistency
          # @return [Models::Node] Node model with full details
          # @raise [ArgumentError] if node name is invalid
          # @raise [Pvectl::ResourceNotFoundError] if node not found
          def describe(name:, node: nil)
            raise ArgumentError, "Invalid node name" unless valid_node_name?(name)

            node = repository.describe(name)
            raise Pvectl::ResourceNotFoundError, "Node not found: #{name}" if node.nil?

            node
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Node] Node repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Node] configured Node repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Node.new(connection)
          end

          # Applies filter criteria to nodes collection.
          #
          # @param nodes [Array<Models::Node>] nodes to filter
          # @param filter [Hash] filter criteria (e.g., { status: "online" })
          # @return [Array<Models::Node>] filtered nodes
          def apply_filters(nodes, filter)
            filter.each do |key, value|
              case key.to_s
              when "status"
                nodes = nodes.select { |n| n.status == value }
              end
            end
            nodes
          end

          # Applies sorting to nodes collection.
          #
          # @param nodes [Array<Models::Node>] nodes to sort
          # @param sort_field [String] field to sort by
          # @return [Array<Models::Node>] sorted nodes
          def apply_sort(nodes, sort_field)
            sort_proc = SORT_FIELDS[sort_field.to_s]
            return nodes unless sort_proc

            nodes.sort_by(&sort_proc)
          end

          # Validates node name format.
          #
          # Proxmox node names are alphanumeric, can contain hyphens,
          # must start with alphanumeric character, max 63 characters.
          #
          # @param name [String, nil] node name to validate
          # @return [Boolean] true if valid
          def valid_node_name?(name)
            return false if name.nil? || name.empty?

            # Proxmox node names: alphanumeric, can contain hyphens, max 63 chars
            name.match?(/\A[a-zA-Z0-9][-a-zA-Z0-9]{0,62}\z/)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "nodes",
  Pvectl::Commands::Get::Handlers::Nodes,
  aliases: ["node"]
)
