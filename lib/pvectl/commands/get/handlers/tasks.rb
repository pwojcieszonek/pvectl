# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for listing Proxmox tasks (async operations).
        #
        # Implements ResourceHandler interface for the "tasks" resource type.
        # Delegates to Services::TaskListing for multi-node task listing.
        #
        # @example Using via ResourceRegistry
        #   handler = ResourceRegistry.for("tasks")
        #   tasks = handler.list(node: "pve1", limit: 20)
        #   presenter = handler.presenter
        #
        # @see Pvectl::Services::TaskListing Shared task listing service
        # @see Pvectl::Presenters::TaskEntry Task entry presenter
        #
        class Tasks
          include ResourceHandler

          # Creates handler with optional service for dependency injection.
          #
          # @param service [Services::TaskListing, nil] task listing service
          def initialize(service: nil)
            @service = service
          end

          # Lists tasks with optional filtering.
          #
          # @param node [String, nil] filter by node name (nil = all nodes)
          # @param name [String, nil] unused, for interface compatibility
          # @param limit [Integer] max entries (default 50)
          # @param since [String, nil] start time filter
          # @param until_time [String, nil] end time filter
          # @param type_filter [String, nil] task type filter
          # @param status_filter [String, nil] status filter
          # @return [Array<Models::TaskEntry>] task entries
          def list(node: nil, name: nil, limit: 50, since: nil, until_time: nil,
                   type_filter: nil, status_filter: nil, **_options)
            service.list(
              node: node, vmid: nil, limit: limit, since: since,
              until_time: until_time, type_filter: type_filter,
              status_filter: status_filter
            )
          end

          # Returns presenter for task entries.
          #
          # @return [Presenters::TaskEntry] task entry presenter instance
          def presenter
            Pvectl::Presenters::TaskEntry.new
          end

          private

          # Returns service, creating it if necessary.
          #
          # @return [Services::TaskListing] task listing service
          def service
            @service ||= build_service
          end

          # Builds service with repositories from config.
          #
          # @return [Services::TaskListing] configured service
          def build_service
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)

            Pvectl::Services::TaskListing.new(
              task_list_repository: Pvectl::Repositories::TaskList.new(connection),
              node_repository: Pvectl::Repositories::Node.new(connection)
            )
          end
        end
      end
    end
  end
end

# Register handler with ResourceRegistry
Pvectl::Commands::Get::ResourceRegistry.register(
  "tasks",
  Pvectl::Commands::Get::Handlers::Tasks,
  aliases: ["task"]
)
