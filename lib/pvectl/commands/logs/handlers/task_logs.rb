# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      module Handlers
        # Handler for VM/CT task history logs.
        #
        # Resolves VM/CT node via repository, then fetches task list
        # from that node. With --all-nodes, iterates all cluster nodes
        # and merges results sorted by start time.
        #
        # @example Using via registry
        #   handler = Logs::ResourceRegistry.for("vm")
        #   entries = handler.list(vmid: 100, resource_type: "vm")
        #
        # @see Pvectl::Repositories::TaskList Task list repository
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
              list_all_nodes(vmid: vmid, limit: limit, since: since,
                             until_time: until_time, type_filter: type_filter,
                             status_filter: status_filter)
            else
              node = resolve_node(vmid, resource_type)
              task_list_repository.list(
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
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            repo_class.new(connection)
          end

          def task_list_repository
            @task_list_repository ||= build_task_list_repository
          end

          def build_task_list_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Repositories::TaskList.new(connection)
          end

          def list_all_nodes(vmid:, limit:, since:, until_time:, type_filter:, status_filter:)
            nodes = node_repository.list.map(&:name)
            entries = nodes.flat_map do |node|
              task_list_repository.list(
                node: node, vmid: vmid, limit: limit, since: since,
                until_time: until_time, type_filter: type_filter,
                status_filter: status_filter
              )
            end
            entries.sort_by { |e| -(e.starttime || 0) }.first(limit)
          end

          def node_repository
            @node_repository ||= begin
              config_service = Pvectl::Config::Service.new
              config_service.load
              connection = Pvectl::Connection.new(config_service.current_config)
              Repositories::Node.new(connection)
            end
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
