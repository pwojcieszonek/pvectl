# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing systemd services on Proxmox nodes.
        #
        # Implements ResourceHandler interface for the "services" resource type.
        # Uses Repositories::Service for data access and Presenters::Service
        # for formatting.
        #
        # When no node filter is supplied, lists services across all online
        # nodes. The --node flag restricts the listing to a single node.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("services")
        #   services = handler.list(node: "pve1")
        #
        # @see Pvectl::Repositories::Service Service repository
        # @see Pvectl::Presenters::Service Service presenter
        #
        class Services
          include ResourceHandler

          # Creates handler with optional repository for dependency injection.
          #
          # @param repository [Repositories::Service, nil] repository (default: build new)
          def initialize(repository: nil)
            @repository = repository
          end

          # Lists services, optionally filtered by node and service name.
          #
          # @param node [String, nil] filter by node name
          # @param name [String, nil] filter by service identifier (exact match)
          # @param _options [Hash] additional CLI options (unused)
          # @return [Array<Models::Service>] collection of Service models
          def list(node: nil, name: nil, **_options)
            services = repository.list(node: node)
            services = services.select { |s| s.service == name } if name
            services
          end

          # Returns presenter for services.
          #
          # @return [Presenters::Service] Service presenter instance
          def presenter
            Pvectl::Presenters::Service.new
          end

          private

          # Returns repository, creating it lazily if not injected.
          #
          # @return [Repositories::Service] Service repository
          def repository
            @repository ||= build_repository
          end

          # Builds repository with connection from config.
          #
          # @return [Repositories::Service] configured Service repository
          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Service.new(connection)
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "services",
  Pvectl::Commands::Get::Handlers::Services,
  aliases: ["svc"]
)
