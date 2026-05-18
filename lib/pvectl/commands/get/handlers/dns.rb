# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for reading per-node DNS resolver settings.
        #
        # Implements ResourceHandler interface for the "dns" resource type.
        # DNS is a singleton resource per node — there is no cluster-wide DNS
        # configuration, so a node name is always required.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("dns")
        #   dns = handler.list(node: "pve1") # => [DnsConfig]
        #
        # @see Pvectl::Repositories::Dns DNS repository
        # @see Pvectl::Presenters::DnsConfig DNS presenter
        #
        class Dns
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Dns, nil] DNS repository
          def initialize(repository: nil)
            @repository = repository
          end

          # Returns the DNS configuration for the given node, wrapped in an array.
          #
          # @param node [String, nil] node name (REQUIRED — DNS is per-node)
          # @param _options [Hash] unused, for interface compatibility
          # @return [Array<Models::DnsConfig>] single-element array with the DNS config
          # @raise [ArgumentError] when no node is provided
          def list(node: nil, **_options)
            raise ArgumentError, "DNS requires --node NODE to identify which node's settings to read" if node.nil? || node.to_s.empty?

            [repository.fetch(node)]
          end

          # Returns presenter for DNS configuration.
          #
          # @return [Presenters::DnsConfig] DNS presenter instance
          def presenter
            Pvectl::Presenters::DnsConfig.new
          end

          # Describes the DNS configuration for a single node.
          #
          # Accepts either `name` (positional argument from describe command)
          # or `node` (--node flag) as the node identifier.
          #
          # @param name [String, nil] node name (positional)
          # @param node [String, nil] node name (--node flag, fallback)
          # @param _opts [Hash] unused, for interface compatibility
          # @return [Models::DnsConfig] DNS configuration model
          # @raise [ArgumentError] when no node identifier given
          def describe(name:, node: nil, **_opts)
            node_name = name || node
            raise ArgumentError, "Node name required: pvectl describe dns NODE or --node NODE" if node_name.nil? || node_name.to_s.empty?

            repository.fetch(node_name)
          end

          private

          # Returns repository, creating it if necessary.
          #
          # @return [Repositories::Dns] DNS repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Dns] configured DNS repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Dns.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "dns",
  Pvectl::Commands::Get::Handlers::Dns
)
