# frozen_string_literal: true

require "test_helper"

class LogsHandlersSyslogTest < Minitest::Test
  def test_list_fetches_syslog
    entry = Pvectl::Models::SyslogEntry.new(n: 1, t: "log line")
    mock_repo = Minitest::Mock.new
    mock_repo.expect :list, [entry], [], node: "pve1", limit: 50,
      since: nil, until_time: nil, service: nil

    handler = Pvectl::Commands::Logs::Handlers::Syslog.new(repository: mock_repo)
    result = handler.list(node: "pve1")

    assert_equal 1, result.size
    mock_repo.verify
  end

  def test_presenter_returns_syslog_entry
    handler = Pvectl::Commands::Logs::Handlers::Syslog.new(repository: Object.new)
    assert_instance_of Pvectl::Presenters::SyslogEntry, handler.presenter
  end
end
