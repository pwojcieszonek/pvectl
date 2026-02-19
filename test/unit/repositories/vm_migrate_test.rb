# frozen_string_literal: true

require "test_helper"

class RepositoriesVmMigrateTest < Minitest::Test
  def test_migrate_posts_to_qemu_migrate_endpoint
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/migrate"])
    mock_endpoint.expect(:post, "UPID:pve1:migrate123", [{ target: "pve2" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.migrate(100, "pve1", { target: "pve2" })

    assert_equal "UPID:pve1:migrate123", result
    mock_client.verify
    mock_endpoint.verify
  end

  def test_migrate_passes_online_parameter
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/migrate"])
    mock_endpoint.expect(:post, "UPID:pve1:migrate123", [{ target: "pve2", online: 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.migrate(100, "pve1", { target: "pve2", online: 1 })

    mock_endpoint.verify
  end

  def test_migrate_passes_with_local_disks_parameter
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/migrate"])
    mock_endpoint.expect(:post, "UPID:pve1:migrate123",
      [{ target: "pve2", online: 1, "with-local-disks": 1 }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.migrate(100, "pve1", { target: "pve2", online: 1, "with-local-disks": 1 })

    mock_endpoint.verify
  end

  def test_migrate_passes_targetstorage_parameter
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/migrate"])
    mock_endpoint.expect(:post, "UPID:pve1:migrate123",
      [{ target: "pve2", targetstorage: "local-lvm" }])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.migrate(100, "pve1", { target: "pve2", targetstorage: "local-lvm" })

    mock_endpoint.verify
  end

  def test_migrate_with_empty_params
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/migrate"])
    mock_endpoint.expect(:post, "UPID:pve1:migrate123", [{}])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.migrate(100, "pve1")

    mock_endpoint.verify
  end
end
