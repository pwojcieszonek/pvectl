# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for reading node systemd journal.
    # Uses GET /nodes/{node}/journal endpoint.
    class Journal < Base
      # @param node [String] node name (required)
      # @param last_entries [Integer] number of recent entries (default 50)
      # @param since [Integer, nil] start time (epoch)
      # @param until_time [Integer, nil] end time (epoch)
      # @return [Array<Models::JournalEntry>]
      def list(node:, last_entries: 50, since: nil, until_time: nil)
        params = { lastentries: last_entries }
        params[:since] = since if since
        params[:until] = until_time if until_time

        response = connection.client["nodes/#{node}/journal"].get(params: params)
        models_from(response, Models::JournalEntry)
      end
    end
  end
end
