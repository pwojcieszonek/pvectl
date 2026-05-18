# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for `pvectl get node-capabilities`.
        #
        # Surfaces what features a node supports — primarily the available
        # QEMU CPU models and machine types. When `--node` is provided the
        # query is scoped to that node; otherwise the handler iterates all
        # online nodes and aggregates the results, silently skipping
        # unreachable nodes (matches the pattern used by the time handler).
        #
        # @see Pvectl::Repositories::Capabilities
        # @see Pvectl::Presenters::Capability
        #
        class Capabilities
          include ResourceHandler

          # @param repository [Repositories::Capabilities, nil] capability repo (DI)
          # @param node_repository [Repositories::Node, nil] node repo (DI)
          def initialize(repository: nil, node_repository: nil)
            @repository = repository
            @node_repository = node_repository
          end

          # Lists capabilities, optionally scoped to a node.
          #
          # @param node [String, nil] when provided, only that node is queried
          # @param name [String, nil] unused, interface compatibility
          # @param args [Array<String>] unused, interface compatibility
          # @param storage [String, nil] unused, interface compatibility
          # @return [Array<Models::Capability>]
          # @raise [Pvectl::ResourceNotFoundError] if a specific node is requested but missing
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            return fetch_for(node) if node

            online_node_names.flat_map do |node_name|
              repository.list(node: node_name)
            rescue StandardError
              []
            end
          end

          # Returns the capability presenter.
          #
          # @return [Presenters::Capability]
          def presenter
            Pvectl::Presenters::Capability.new
          end

          private

          # Fetches capabilities for a specific node, raising when the node
          # itself does not exist in the cluster.
          #
          # @param node_name [String]
          # @return [Array<Models::Capability>]
          # @raise [Pvectl::ResourceNotFoundError]
          def fetch_for(node_name)
            unless node_repository.get(node_name)
              raise Pvectl::ResourceNotFoundError, "Node not found: #{node_name}"
            end

            repository.list(node: node_name)
          end

          # Names of online nodes.
          #
          # @return [Array<String>]
          def online_node_names
            node_repository.list.select { |n| n.status == "online" }.map(&:name)
          end

          # @return [Repositories::Capabilities]
          def repository
            @repository ||= Pvectl::Repositories::Capabilities.new(connection)
          end

          # @return [Repositories::Node]
          def node_repository
            @node_repository ||= Pvectl::Repositories::Node.new(connection)
          end

          # Builds API connection from the current config.
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

# Register handler with ResourceRegistry under the spec name plus aliases.
Pvectl::Commands::Get::ResourceRegistry.register(
  "node-capabilities",
  Pvectl::Commands::Get::Handlers::Capabilities,
  aliases: ["capabilities", "caps", "node-capability"]
)
