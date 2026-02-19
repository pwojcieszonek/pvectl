# frozen_string_literal: true

module Pvectl
  module Models
    # Represents an entry in a node's task list.
    #
    # Each entry corresponds to an asynchronous operation (start, stop,
    # migrate, backup, etc.) performed on a resource. Returned by
    # GET /nodes/{node}/tasks endpoint.
    #
    # @example
    #   entry = TaskEntry.new(type: "qmstart", status: "stopped", exitstatus: "OK")
    #   entry.successful? #=> true
    #
    class TaskEntry < Base
      attr_reader :upid, :node, :type, :status, :exitstatus,
                  :starttime, :endtime, :user, :id, :pid, :pstart

      def initialize(attrs = {})
        super(attrs)
        @upid = @attributes[:upid]
        @node = @attributes[:node]
        @type = @attributes[:type]
        @status = @attributes[:status]
        @exitstatus = @attributes[:exitstatus]
        @starttime = @attributes[:starttime]
        @endtime = @attributes[:endtime]
        @user = @attributes[:user]
        @id = @attributes[:id]
        @pid = @attributes[:pid]
        @pstart = @attributes[:pstart]
      end

      def successful?
        completed? && exitstatus == "OK"
      end

      def failed?
        completed? && exitstatus != "OK"
      end

      def completed?
        status != "running"
      end

      def duration
        return nil unless endtime && starttime
        endtime - starttime
      end
    end
  end
end
