# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a syslog line from GET /nodes/{node}/syslog.
    # Proxmox returns syslog entries as {n: line_number, t: text}.
    class SyslogEntry < Base
      attr_reader :n, :t

      def initialize(attrs = {})
        super(attrs)
        @n = @attributes[:n]
        @t = @attributes[:t]
      end
    end
  end
end
