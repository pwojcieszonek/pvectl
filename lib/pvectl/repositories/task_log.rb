# frozen_string_literal: true

require "cgi"

module Pvectl
  module Repositories
    # Repository for reading a specific task's log output.
    # Uses GET /nodes/{node}/tasks/{upid}/log endpoint.
    class TaskLog < Base
      # @param upid [String] task UPID
      # @param start [Integer] line offset (default 0)
      # @param limit [Integer] max lines (default 512)
      # @return [Array<Models::TaskLogLine>]
      def list(upid:, start: 0, limit: 512)
        node = extract_node_from_upid(upid)
        escaped = CGI.escape(upid)

        response = connection.client["nodes/#{node}/tasks/#{escaped}/log"].get(
          params: { start: start, limit: limit }
        )
        models_from(response, Models::TaskLogLine)
      end

      private

      def extract_node_from_upid(upid)
        upid.split(":")[1]
      end
    end
  end
end
