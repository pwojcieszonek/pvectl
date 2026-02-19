# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for reading node syslog.
    # Uses GET /nodes/{node}/syslog endpoint.
    class Syslog < Base
      # @param node [String] node name (required)
      # @param limit [Integer] max entries (default 50)
      # @param since [String, nil] start timestamp
      # @param until_time [String, nil] end timestamp
      # @param service [String, nil] filter by service name
      # @return [Array<Models::SyslogEntry>]
      def list(node:, limit: 50, since: nil, until_time: nil, service: nil)
        params = { limit: limit }
        params[:since] = since if since
        params[:until] = until_time if until_time
        params[:service] = service if service

        response = connection.client["nodes/#{node}/syslog"].get(params: params)
        models_from(response, Models::SyslogEntry)
      end
    end
  end
end
