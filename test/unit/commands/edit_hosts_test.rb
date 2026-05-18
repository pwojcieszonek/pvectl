# frozen_string_literal: true

require "test_helper"

module Pvectl
  module Commands
    class EditHostsTest < Minitest::Test
      def test_usage_error_when_no_node
        out, err = capture_io do
          @code = EditHosts.execute([], {}, {})
        end
        assert_equal Pvectl::ExitCodes::USAGE_ERROR, @code
        assert_match(/NODE is required/, err)
        assert_empty out
      end
    end
  end
end
