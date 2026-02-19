# frozen_string_literal: true

require "test_helper"

class SyslogEntryModelTest < Minitest::Test
  def test_attributes
    entry = Pvectl::Models::SyslogEntry.new(n: 1, t: "Feb 19 14:32:01 pve1 pvedaemon[1234]: starting VM 100")
    assert_equal 1, entry.n
    assert_equal "Feb 19 14:32:01 pve1 pvedaemon[1234]: starting VM 100", entry.t
  end
end
