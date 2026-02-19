# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a systemd journal line from GET /nodes/{node}/journal.
    class JournalEntry < Base
      attr_reader :n, :t

      def initialize(attrs = {})
        super(attrs)
        @n = @attributes[:n]
        @t = @attributes[:t]
      end
    end
  end
end
