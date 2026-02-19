# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for task list entries (pvectl logs vm/ct).
    class TaskEntry < Base
      def columns
        %w[STARTTIME TYPE STATUS USER DURATION NODE]
      end

      def extra_columns
        %w[UPID ENDTIME ID PID]
      end

      def to_row(model, **_context)
        [
          format_time(model.starttime),
          model.type || "-",
          model.exitstatus || model.status || "-",
          model.user || "-",
          format_duration(model.duration),
          model.node || "-"
        ]
      end

      def extra_values(model, **_context)
        [
          model.upid || "-",
          format_time(model.endtime),
          model.id || "-",
          model.pid&.to_s || "-"
        ]
      end

      def to_hash(model)
        {
          "starttime" => model.starttime,
          "endtime" => model.endtime,
          "type" => model.type,
          "status" => model.status,
          "exitstatus" => model.exitstatus,
          "user" => model.user,
          "duration" => model.duration,
          "node" => model.node,
          "id" => model.id,
          "upid" => model.upid
        }
      end

      private

      def format_time(timestamp)
        return "-" if timestamp.nil?
        Time.at(timestamp).strftime("%Y-%m-%d %H:%M:%S")
      end

      def format_duration(seconds)
        return "-" if seconds.nil?
        if seconds < 60
          "#{seconds}s"
        elsif seconds < 3600
          "#{seconds / 60}m#{seconds % 60}s"
        else
          "#{seconds / 3600}h#{(seconds % 3600) / 60}m"
        end
      end
    end
  end
end
