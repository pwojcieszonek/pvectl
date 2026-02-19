# frozen_string_literal: true

module Pvectl
  module Repositories
    # Repository for listing tasks (async operations) on a node.
    # Uses GET /nodes/{node}/tasks to fetch recent operations.
    class TaskList < Base
      # @param node [String] node name (required)
      # @param vmid [Integer, nil] filter by VMID
      # @param limit [Integer] max entries (default 50)
      # @param since [Integer, nil] start time (epoch)
      # @param until_time [Integer, nil] end time (epoch)
      # @param type_filter [String, nil] filter by task type
      # @param status_filter [String, nil] filter by status
      # @return [Array<Models::TaskEntry>]
      def list(node:, vmid: nil, limit: 50, since: nil, until_time: nil,
               type_filter: nil, status_filter: nil)
        params = { limit: limit, source: "all" }
        params[:vmid] = vmid if vmid
        params[:since] = since if since
        params[:until] = until_time if until_time
        params[:typefilter] = type_filter if type_filter
        params[:statusfilter] = status_filter if status_filter

        response = connection.client["nodes/#{node}/tasks"].get(params: params)
        models_from(response, Models::TaskEntry)
      end
    end
  end
end
