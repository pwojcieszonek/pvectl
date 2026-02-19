# frozen_string_literal: true

require "test_helper"

class LogsHandlersJournalTest < Minitest::Test
  def test_list_fetches_journal
    entry = Pvectl::Models::JournalEntry.new(n: 1, t: "journal line")
    mock_repo = Minitest::Mock.new
    mock_repo.expect :list, [entry], [], node: "pve1", last_entries: 50,
      since: nil, until_time: nil

    handler = Pvectl::Commands::Logs::Handlers::Journal.new(repository: mock_repo)
    result = handler.list(node: "pve1")

    assert_equal 1, result.size
    mock_repo.verify
  end

  def test_presenter_returns_journal_entry
    handler = Pvectl::Commands::Logs::Handlers::Journal.new(repository: Object.new)
    assert_instance_of Pvectl::Presenters::JournalEntry, handler.presenter
  end
end
