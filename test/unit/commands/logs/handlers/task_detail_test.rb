# frozen_string_literal: true

require "test_helper"

class LogsHandlersTaskDetailTest < Minitest::Test
  def test_list_fetches_task_log
    line = Pvectl::Models::TaskLogLine.new(n: 1, t: "starting VM")
    mock_repo = Minitest::Mock.new
    mock_repo.expect :list, [line], [], upid: "UPID:pve1:...", start: 0, limit: 512

    handler = Pvectl::Commands::Logs::Handlers::TaskDetail.new(repository: mock_repo)
    result = handler.list(upid: "UPID:pve1:...")

    assert_equal 1, result.size
    mock_repo.verify
  end

  def test_presenter_returns_task_log_line
    handler = Pvectl::Commands::Logs::Handlers::TaskDetail.new(repository: Object.new)
    assert_instance_of Pvectl::Presenters::TaskLogLine, handler.presenter
  end
end
