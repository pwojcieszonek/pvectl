# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a Proxmox task (asynchronous operation).
    #
    # Tasks are returned by lifecycle operations (start, stop, etc.).
    # The UPID (Unique Process ID) identifies the task.
    #
    # @example Creating a Task model
    #   task = Task.new(upid: "UPID:pve1:...", status: "running")
    #   task.pending? #=> true
    #   task.completed? #=> false
    #
    # @see Pvectl::Repositories::Task Repository that creates Task instances
    #
    class Task < Base
      # @return [String] Unique Process ID
      attr_reader :upid

      # @return [String] Node where task runs
      attr_reader :node

      # @return [String] Task type (qmstart, qmstop, etc.)
      attr_reader :type

      # @return [String] Task status (running, stopped)
      attr_reader :status

      # @return [String, nil] Exit status (OK, ERROR, etc.)
      attr_reader :exitstatus

      # @return [Integer, nil] Task start time (Unix timestamp)
      attr_reader :starttime

      # @return [Integer, nil] Task end time (Unix timestamp)
      attr_reader :endtime

      # @return [String, nil] User who started the task
      attr_reader :user

      # Creates a new Task model from attributes.
      #
      # @param attrs [Hash] Task attributes from API
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
      end

      # Checks if the task is still running.
      #
      # @return [Boolean] true if status is "running"
      def pending?
        status == "running"
      end

      # Checks if the task has completed.
      #
      # @return [Boolean] true if status is not "running"
      def completed?
        !pending?
      end

      # Checks if the task completed successfully.
      #
      # @return [Boolean] true if completed with "OK" exitstatus
      def successful?
        completed? && exitstatus == "OK"
      end

      # Checks if the task failed.
      #
      # @return [Boolean] true if completed with non-OK exitstatus
      def failed?
        completed? && exitstatus != "OK"
      end

      # Returns task duration in seconds.
      #
      # @return [Integer, nil] duration or nil if not available
      def duration
        return nil unless endtime && starttime

        endtime - starttime
      end
    end
  end
end
