# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for reading per-node /etc/hosts contents.
        #
        # Implements ResourceHandler interface for the "hosts" resource type.
        # /etc/hosts is a singleton resource per node — there is no cluster-wide
        # hosts file, so a node name is always required.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("hosts")
        #   hosts = handler.list(node: "pve1") # => [HostsFile]
        #
        # @see Pvectl::Repositories::Hosts Hosts repository
        # @see Pvectl::Presenters::HostsFile HostsFile presenter
        #
        class Hosts
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Hosts, nil] Hosts repository
          def initialize(repository: nil)
            @repository = repository
          end

          # Returns the /etc/hosts contents for the given node, wrapped in an array.
          #
          # @param node [String, nil] node name (REQUIRED — hosts is per-node)
          # @param _options [Hash] unused, for interface compatibility
          # @return [Array<Models::HostsFile>] single-element array with the hosts file
          # @raise [ArgumentError] when no node is provided
          def list(node: nil, **_options)
            raise ArgumentError, "hosts requires --node NODE to identify which node's /etc/hosts to read" if node.nil? || node.to_s.empty?

            [repository.fetch(node)]
          end

          # Returns presenter for /etc/hosts.
          #
          # @return [Presenters::HostsFile] HostsFile presenter instance
          def presenter
            Pvectl::Presenters::HostsFile.new
          end

          # Describes the /etc/hosts contents for a single node.
          #
          # Accepts either `name` (positional argument from describe command)
          # or `node` (--node flag) as the node identifier.
          #
          # @param name [String, nil] node name (positional)
          # @param node [String, nil] node name (--node flag, fallback)
          # @param _opts [Hash] unused, for interface compatibility
          # @return [Models::HostsFile] hosts file model
          # @raise [ArgumentError] when no node identifier given
          def describe(name:, node: nil, **_opts)
            node_name = name || node
            raise ArgumentError, "Node name required: pvectl describe hosts NODE or --node NODE" if node_name.nil? || node_name.to_s.empty?

            repository.fetch(node_name)
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Hosts] hosts repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Hosts] configured hosts repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Hosts.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "hosts",
  Pvectl::Commands::Get::Handlers::Hosts
)
