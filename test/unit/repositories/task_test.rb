# frozen_string_literal: true

require "test_helper"

class RepositoriesTaskTest < Minitest::Test
  def test_task_repository_class_exists
    assert_kind_of Class, Pvectl::Repositories::Task
  end

  def test_task_repository_inherits_from_base
    assert Pvectl::Repositories::Task < Pvectl::Repositories::Base
  end

  def test_find_returns_task_model
    repo = create_repo_with_mock_response(status: "running", type: "qmstart")

    task = repo.find("UPID:pve1:000ABC:123:456:qmstart:100:root@pam:")

    assert_instance_of Pvectl::Models::Task, task
    assert_equal "running", task.status
    assert_equal "qmstart", task.type
  end

  def test_find_extracts_node_from_upid
    mock_connection = MockTaskConnection.new(
      expected_node: "pve2",
      response: { status: "stopped", exitstatus: "OK" }
    )
    repo = Pvectl::Repositories::Task.new(mock_connection)

    task = repo.find("UPID:pve2:000ABC:123:456:qmstop:100:root@pam:")

    assert_equal "pve2", mock_connection.requested_node
    assert task.completed?
  end

  def test_find_returns_completed_task_with_exitstatus
    repo = create_repo_with_mock_response(
      status: "stopped",
      exitstatus: "OK",
      starttime: 1707000000,
      endtime: 1707000030
    )

    task = repo.find("UPID:pve1:000ABC:...")

    assert task.completed?
    assert task.successful?
    assert_equal 30, task.duration
  end

  private

  def create_repo_with_mock_response(response)
    mock_connection = MockTaskConnection.new(response: response)
    Pvectl::Repositories::Task.new(mock_connection)
  end

  class MockTaskConnection
    attr_reader :requested_node

    def initialize(expected_node: "pve1", response:)
      @expected_node = expected_node
      @response = response
    end

    def client
      @client ||= MockTaskClient.new(self, @response)
    end

    def record_node(node)
      @requested_node = node
    end
  end

  class MockTaskClient
    def initialize(connection, response)
      @connection = connection
      @response = response
    end

    def [](path)
      # Extract node from path like "nodes/pve1/tasks/UPID:.../status"
      if path.match?(%r{^nodes/([^/]+)/tasks/})
        node = path.split("/")[1]
        @connection.record_node(node)
      end
      MockTaskResource.new(@response)
    end
  end

  class MockTaskResource
    def initialize(response)
      @response = response
    end

    def get
      @response
    end
  end
end
