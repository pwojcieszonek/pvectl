# frozen_string_literal: true

require "cgi"

module Pvectl
  module Repositories
    # Repository for Proxmox tasks (async operations).
    #
    # Tasks are identified by UPID (Unique Process ID) which encodes
    # the node name, allowing us to query the correct node.
    #
    # @example Finding a task
    #   repo = Task.new(connection)
    #   task = repo.find("UPID:pve1:000ABC:...")
    #   task.completed? #=> true/false
    #
    class Task < Base
      # Finds a task by UPID.
      #
      # @param upid [String] Unique Process ID
      # @return [Models::Task] Task model
      def find(upid)
        node = extract_node_from_upid(upid)
        response = connection.client["nodes/#{node}/tasks/#{CGI.escape(upid)}/status"].get
        data = extract_data(response)
        build_model(data.merge(upid: upid))
      end

      # Waits for a task to complete.
      #
      # @param upid [String] Task UPID
      # @param timeout [Integer] Max wait time in seconds
      # @param interval [Integer] Poll interval in seconds
      # @return [Models::Task] Completed task
      # @raise [Timeout::Error] if task doesn't complete in time
      def wait(upid, timeout: 60, interval: 2)
        deadline = Time.now + timeout
        loop do
          task = find(upid)
          return task if task.completed?

          if Time.now > deadline
            raise Timeout::Error, "Task #{upid} timed out after #{timeout}s"
          end

          sleep interval
        end
      end

      # Not implemented - tasks are looked up by UPID, not listed
      def list
        raise NotImplementedError, "Use find(upid) to get task status"
      end

      # Not implemented - use find instead
      def get(id)
        find(id)
      end

      protected

      # Builds Task model from API response.
      #
      # @param data [Hash] API response
      # @return [Models::Task] Task model
      def build_model(data)
        Models::Task.new(data)
      end

      private

      # Extracts node name from UPID.
      # UPID format: UPID:node:pid:pstart:starttime:type:id:user:
      #
      # @param upid [String] UPID string
      # @return [String] Node name
      def extract_node_from_upid(upid)
        upid.split(":")[1]
      end
    end
  end
end
