# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing node time and timezone settings.
        #
        # Implements ResourceHandler interface for the "time" resource type.
        # When `--node` is supplied, returns the time config for that single node.
        # Otherwise, iterates over all online nodes and aggregates their time configs.
        # Unreachable nodes (those that raise during fetch) are silently skipped so
        # one bad node does not abort the whole listing.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("time")
        #   configs = handler.list(node: "pve1")
        #
        # @see Pvectl::Commands::Get::ResourceHandler Handler interface
        # @see Pvectl::Repositories::TimeConfig Time repository
        # @see Pvectl::Presenters::TimeConfig Time presenter
        #
        class Time
          include ResourceHandler

          # Creates handler with optional repositories for dependency injection.
          #
          # @param repository [Repositories::TimeConfig, nil] time repository
          # @param node_repository [Repositories::Node, nil] node repository
          def initialize(repository: nil, node_repository: nil)
            @repository = repository
            @node_repository = node_repository
          end

          # Lists time/timezone configs.
          #
          # @param node [String, nil] when given, only that node is queried;
          #   otherwise iterates all online nodes
          # @param name [String, nil] unused, for interface compatibility
          # @param args [Array<String>] unused, for interface compatibility
          # @param storage [String, nil] unused, for interface compatibility
          # @return [Array<Models::TimeConfig>] one entry per node queried
          # @raise [Pvectl::ResourceNotFoundError] if a specific node was requested but does not exist
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            return [fetch_for(node)] if node

            online_node_names.filter_map do |node_name|
              begin
                repository.fetch(node_name)
              rescue StandardError
                # Skip unreachable nodes - one bad node should not abort the listing.
                nil
              end
            end
          end

          # Returns presenter for time configs.
          #
          # @return [Presenters::TimeConfig]
          def presenter
            Pvectl::Presenters::TimeConfig.new
          end

          private

          # Fetches the time config for a specific node, raising ResourceNotFoundError
          # if the node itself does not exist in the cluster.
          #
          # @param node_name [String] node name
          # @return [Models::TimeConfig]
          # @raise [Pvectl::ResourceNotFoundError] if the node does not exist
          def fetch_for(node_name)
            unless node_repository.get(node_name)
              raise Pvectl::ResourceNotFoundError, "Node not found: #{node_name}"
            end

            repository.fetch(node_name)
          end

          # Names of online nodes (offline nodes are skipped because querying
          # them is guaranteed to fail).
          #
          # @return [Array<String>] node names
          def online_node_names
            node_repository.list.select { |n| n.status == "online" }.map(&:name)
          end

          # @return [Repositories::TimeConfig] time repository, lazily built
          def repository
            @repository ||= Pvectl::Repositories::TimeConfig.new(connection)
          end

          # @return [Repositories::Node] node repository, lazily built
          def node_repository
            @node_repository ||= Pvectl::Repositories::Node.new(connection)
          end

          # Builds API connection from current config.
          #
          # @return [Pvectl::Connection]
          def connection
            @connection ||= begin
              config_service = Pvectl::Config::Service.new
              config_service.load
              Pvectl::Connection.new(config_service.current_config)
            end
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "time",
  Pvectl::Commands::Get::Handlers::Time
)
