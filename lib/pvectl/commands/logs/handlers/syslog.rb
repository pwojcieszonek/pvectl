# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      module Handlers
        # Handler for node syslog output.
        #
        # Fetches syslog entries from a node via Repositories::Syslog.
        # Supports filtering by service name and time range.
        #
        # @example Using via registry
        #   handler = Logs::ResourceRegistry.for("node")
        #   entries = handler.list(node: "pve1", service: "pvedaemon")
        #
        # @see Pvectl::Repositories::Syslog Syslog repository
        # @see Pvectl::Presenters::SyslogEntry Syslog presenter
        #
        class Syslog
          include Logs::ResourceHandler

          def initialize(repository: nil)
            @repository = repository
          end

          def list(node:, limit: 50, since: nil, until_time: nil, service: nil, **_)
            repository.list(node: node, limit: limit, since: since,
                            until_time: until_time, service: service)
          end

          def presenter
            Presenters::SyslogEntry.new
          end

          private

          def repository
            @repository ||= begin
              config_service = Pvectl::Config::Service.new
              config_service.load
              connection = Pvectl::Connection.new(config_service.current_config)
              Repositories::Syslog.new(connection)
            end
          end
        end
      end
    end
  end
end

Pvectl::Commands::Logs::ResourceRegistry.register(
  "node", Pvectl::Commands::Logs::Handlers::Syslog, aliases: ["nodes"]
)
