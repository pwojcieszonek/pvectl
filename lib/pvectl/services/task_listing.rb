# frozen_string_literal: true

module Pvectl
  module Services
    # Service for listing tasks across one or all cluster nodes.
    #
    # Encapsulates multi-node iteration, merge, sort, and limit logic.
    # Used by both Get::Handlers::Tasks and Logs::Handlers::TaskLogs.
    #
    # @example List all tasks cluster-wide
    #   service = TaskListing.new(task_list_repository: repo, node_repository: node_repo)
    #   tasks = service.list(limit: 20)
    #
    # @example List tasks on a specific node
    #   tasks = service.list(node: "pve1", type_filter: "vzdump")
    #
    class TaskListing
      # Creates a new TaskListing service.
      #
      # @param task_list_repository [Repositories::TaskList] task list repository
      # @param node_repository [Repositories::Node] node repository for cluster discovery
      def initialize(task_list_repository:, node_repository:)
        @task_list_repository = task_list_repository
        @node_repository = node_repository
      end

      # Lists tasks, optionally filtered.
      #
      # When node is nil, iterates all cluster nodes and merges results
      # sorted by starttime descending.
      #
      # @param node [String, nil] specific node or nil for all nodes
      # @param vmid [Integer, nil] filter by VMID
      # @param limit [Integer] max entries (default 50)
      # @param since [String, nil] start time filter
      # @param until_time [String, nil] end time filter
      # @param type_filter [String, nil] task type filter
      # @param status_filter [String, nil] status filter
      # @return [Array<Models::TaskEntry>] task entries
      def list(node: nil, vmid: nil, limit: 50, since: nil, until_time: nil,
               type_filter: nil, status_filter: nil)
        if node
          @task_list_repository.list(
            node: node, vmid: vmid, limit: limit, since: since,
            until_time: until_time, type_filter: type_filter,
            status_filter: status_filter
          )
        else
          list_all_nodes(
            vmid: vmid, limit: limit, since: since,
            until_time: until_time, type_filter: type_filter,
            status_filter: status_filter
          )
        end
      end

      private

      # Iterates all cluster nodes and merges results.
      #
      # @return [Array<Models::TaskEntry>] merged and sorted entries
      def list_all_nodes(vmid:, limit:, since:, until_time:, type_filter:, status_filter:)
        nodes = @node_repository.list.map(&:name)
        entries = nodes.flat_map do |node_name|
          @task_list_repository.list(
            node: node_name, vmid: vmid, limit: limit, since: since,
            until_time: until_time, type_filter: type_filter,
            status_filter: status_filter
          )
        end
        entries.sort_by { |e| -(e.starttime || 0) }.first(limit)
      end
    end
  end
end
