# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      module Handlers
        # Handler for task log drill-down by UPID.
        #
        # Fetches individual task log lines from the Proxmox API.
        # Extracts the node name from the UPID for API routing.
        #
        # @example Using via registry
        #   handler = Logs::ResourceRegistry.for("task")
        #   lines = handler.list(upid: "UPID:pve1:000ABC:...")
        #
        # @see Pvectl::Repositories::TaskLog Task log repository
        # @see Pvectl::Presenters::TaskLogLine Task log line presenter
        #
        class TaskDetail
          include Logs::ResourceHandler

          def initialize(repository: nil)
            @repository = repository
          end

          def list(upid:, start: 0, limit: 512, **_)
            repository.list(upid: upid, start: start, limit: limit)
          end

          def presenter
            Presenters::TaskLogLine.new
          end

          private

          def repository
            @repository ||= begin
              config_service = Pvectl::Config::Service.new
              config_service.load
              connection = Pvectl::Connection.new(config_service.current_config)
              Repositories::TaskLog.new(connection)
            end
          end
        end
      end
    end
  end
end

Pvectl::Commands::Logs::ResourceRegistry.register(
  "task", Pvectl::Commands::Logs::Handlers::TaskDetail
)
