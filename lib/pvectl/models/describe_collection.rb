# frozen_string_literal: true

module Pvectl
  module Models
    # An array of describe models that must each be rendered in full describe
    # format (used when an identifier matches several resources by name).
    #
    # Distinguished from a plain Array, which the describe service renders as a
    # single table (e.g. storage instances across nodes).
    #
    class DescribeCollection < Array; end
  end
end
