# frozen_string_literal: true

require "test_helper"

class SyslogEntryPresenterTest < Minitest::Test
  def setup
    @presenter = Pvectl::Presenters::SyslogEntry.new
    @entry = Pvectl::Models::SyslogEntry.new(n: 1, t: "Feb 19 14:32:01 pve1 pvedaemon: start")
  end

  def test_columns
    assert_equal %w[LINE TEXT], @presenter.columns
  end

  def test_to_row
    assert_equal ["1", "Feb 19 14:32:01 pve1 pvedaemon: start"], @presenter.to_row(@entry)
  end

  def test_to_hash
    hash = @presenter.to_hash(@entry)
    assert_equal 1, hash["line"]
    assert_equal "Feb 19 14:32:01 pve1 pvedaemon: start", hash["text"]
  end
end

class JournalEntryPresenterTest < Minitest::Test
  def test_columns
    assert_equal %w[LINE TEXT], Pvectl::Presenters::JournalEntry.new.columns
  end

  def test_to_row
    entry = Pvectl::Models::JournalEntry.new(n: 5, t: "journal line")
    assert_equal ["5", "journal line"], Pvectl::Presenters::JournalEntry.new.to_row(entry)
  end
end

class TaskLogLinePresenterTest < Minitest::Test
  def test_columns
    assert_equal %w[LINE TEXT], Pvectl::Presenters::TaskLogLine.new.columns
  end

  def test_to_row
    line = Pvectl::Models::TaskLogLine.new(n: 1, t: "starting VM 100")
    assert_equal ["1", "starting VM 100"], Pvectl::Presenters::TaskLogLine.new.to_row(line)
  end
end
