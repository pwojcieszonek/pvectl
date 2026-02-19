# frozen_string_literal: true

require "test_helper"

class RepositoriesVmCreateTest < Minitest::Test
  def test_create_posts_to_qemu_endpoint_with_vmid_merged_into_params
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, "UPID:pve1:create", [{ vmid: 100, name: "test-vm" }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu"])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.create("pve1", 100, { name: "test-vm" })

    assert_equal "UPID:pve1:create", result
    mock_endpoint.verify
    mock_client.verify
  end

  def test_create_passes_all_params_to_api_endpoint
    params = {
      name: "web",
      cores: 4,
      sockets: 1,
      memory: 4096,
      ostype: "l26",
      scsi0: "local-lvm:32,format=raw",
      scsihw: "virtio-scsi-single",
      net0: "virtio,bridge=vmbr0"
    }

    expected_api_params = params.merge(vmid: 200)

    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, "UPID:pve2:create", [expected_api_params])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["nodes/pve2/qemu"])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.create("pve2", 200, params)

    assert_equal "UPID:pve2:create", result
    mock_endpoint.verify
  end

  def test_create_works_with_empty_params
    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, "UPID:pve1:create", [{ vmid: 100 }])

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu"])

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.create("pve1", 100)

    assert_equal "UPID:pve1:create", result
    mock_endpoint.verify
  end
end
