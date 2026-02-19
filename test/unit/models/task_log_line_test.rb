# frozen_string_literal: true

require "test_helper"

class TaskLogLineModelTest < Minitest::Test
  def test_attributes
    line = Pvectl::Models::TaskLogLine.new(n: 1, t: "starting VM 100 on 'pve1'")
    assert_equal 1, line.n
    assert_equal "starting VM 100 on 'pve1'", line.t
  end
end
