# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      module Handlers
        # Handler for VM/CT task history logs.
        #
        # Resolves VM/CT node via repository, then delegates task listing
        # to Services::TaskListing. With --all-nodes, passes node: nil
        # to the service for cluster-wide iteration.
        #
        # @example Using via registry
        #   handler = Logs::ResourceRegistry.for("vm")
        #   entries = handler.list(vmid: 100, resource_type: "vm")
        #
        # @see Pvectl::Services::TaskListing Shared task listing service
        # @see Pvectl::Presenters::TaskEntry Task entry presenter
        #
        class TaskLogs
          include Logs::ResourceHandler

          # Maps resource type aliases to repository classes.
          RESOURCE_REPOS = {
            "vm" => -> { Pvectl::Repositories::Vm },
            "vms" => -> { Pvectl::Repositories::Vm },
            "ct" => -> { Pvectl::Repositories::Container },
            "container" => -> { Pvectl::Repositories::Container },
            "containers" => -> { Pvectl::Repositories::Container },
            "cts" => -> { Pvectl::Repositories::Container }
          }.freeze

          def initialize(task_list_repository: nil, vm_repository: nil, node_repository: nil)
            @task_list_repository = task_list_repository
            @vm_repository = vm_repository
            @node_repository = node_repository
          end

          def list(vmid:, resource_type: "vm", all_nodes: false, limit: 50,
                   since: nil, until_time: nil, type_filter: nil, status_filter: nil, **_)
            if all_nodes
              service.list(
                vmid: vmid, limit: limit, since: since,
                until_time: until_time, type_filter: type_filter,
                status_filter: status_filter
              )
            else
              node = resolve_node(vmid, resource_type)
              service.list(
                node: node, vmid: vmid, limit: limit, since: since,
                until_time: until_time, type_filter: type_filter,
                status_filter: status_filter
              )
            end
          end

          def presenter
            Presenters::TaskEntry.new
          end

          private

          def resolve_node(vmid, resource_type)
            resource = resource_repository(resource_type).get(vmid)
            raise ResourceNotFoundError, "Resource not found: #{vmid}" unless resource

            resource.node
          end

          def resource_repository(resource_type)
            @vm_repository || build_resource_repository(resource_type)
          end

          def build_resource_repository(resource_type)
            repo_class = RESOURCE_REPOS.fetch(resource_type, -> { Pvectl::Repositories::Vm }).call
            connection = build_connection
            repo_class.new(connection)
          end

          def service
            @service ||= Pvectl::Services::TaskListing.new(
              task_list_repository: task_list_repository,
              node_repository: node_repository
            )
          end

          def task_list_repository
            @task_list_repository ||= begin
              connection = build_connection
              Repositories::TaskList.new(connection)
            end
          end

          def node_repository
            @node_repository ||= begin
              connection = build_connection
              Repositories::Node.new(connection)
            end
          end

          def build_connection
            config_service = Pvectl::Config::Service.new
            config_service.load
            Pvectl::Connection.new(config_service.current_config)
          end
        end
      end
    end
  end
end

Pvectl::Commands::Logs::ResourceRegistry.register(
  "vm", Pvectl::Commands::Logs::Handlers::TaskLogs,
  aliases: ["vms", "ct", "container", "containers", "cts"]
)
