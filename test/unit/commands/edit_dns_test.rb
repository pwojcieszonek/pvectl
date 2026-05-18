# frozen_string_literal: true

require "test_helper"

class EditDnsTest < Minitest::Test
  def test_requires_node_argument
    out = capture_io do
      @exit_code = Pvectl::Commands::EditDns.execute([], {}, {})
    end
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, @exit_code
    assert_match(/node/i, out.join)
  end

  def test_empty_node_string_treated_as_missing
    out = capture_io do
      @exit_code = Pvectl::Commands::EditDns.execute([""], {}, {})
    end
    assert_equal Pvectl::ExitCodes::USAGE_ERROR, @exit_code
    assert_match(/node/i, out.join)
  end

  def test_class_exposes_execute_class_method
    assert_respond_to Pvectl::Commands::EditDns, :execute
  end
end
