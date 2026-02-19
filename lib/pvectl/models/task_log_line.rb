# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a single line from a task's log output.
    # Returned by GET /nodes/{node}/tasks/{upid}/log.
    class TaskLogLine < Base
      attr_reader :n, :t

      def initialize(attrs = {})
        super(attrs)
        @n = @attributes[:n]
        @t = @attributes[:t]
      end
    end
  end
end
