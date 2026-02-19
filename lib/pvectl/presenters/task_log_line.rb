# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for task log lines (pvectl logs task UPID).
    class TaskLogLine < Base
      def columns
        %w[LINE TEXT]
      end

      def to_row(model, **_context)
        [model.n.to_s, model.t || ""]
      end

      def to_hash(model)
        { "line" => model.n, "text" => model.t }
      end
    end
  end
end
