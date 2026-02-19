# frozen_string_literal: true

require "test_helper"

class JournalEntryModelTest < Minitest::Test
  def test_attributes
    entry = Pvectl::Models::JournalEntry.new(n: 5, t: "Feb 19 systemd[1]: Started VM")
    assert_equal 5, entry.n
    assert_equal "Feb 19 systemd[1]: Started VM", entry.t
  end
end
