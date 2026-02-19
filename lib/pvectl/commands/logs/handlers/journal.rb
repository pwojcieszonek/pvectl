# frozen_string_literal: true

module Pvectl
  module Commands
    module Logs
      module Handlers
        # Handler for node systemd journal output.
        #
        # Fetches journal entries from a node via Repositories::Journal.
        # Not registered in ResourceRegistry — created by Command
        # when --journal flag is set.
        #
        # @see Pvectl::Repositories::Journal Journal repository
        # @see Pvectl::Presenters::JournalEntry Journal presenter
        #
        class Journal
          include Logs::ResourceHandler

          def initialize(repository: nil)
            @repository = repository
          end

          def list(node:, limit: 50, since: nil, until_time: nil, **_)
            repository.list(node: node, last_entries: limit, since: since,
                            until_time: until_time)
          end

          def presenter
            Presenters::JournalEntry.new
          end

          private

          def repository
            @repository ||= begin
              config_service = Pvectl::Config::Service.new
              config_service.load
              connection = Pvectl::Connection.new(config_service.current_config)
              Repositories::Journal.new(connection)
            end
          end
        end
      end
    end
  end
end
