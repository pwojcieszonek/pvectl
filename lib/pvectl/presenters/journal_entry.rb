# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for systemd journal entries (pvectl logs node --journal).
    class JournalEntry < Base
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
