# frozen_string_literal: true

require "test_helper"

class RepositoriesVmFeatureTest < Minitest::Test
  def test_feature_available_gets_with_correct_params
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/feature"])
    mock_endpoint.expect(
      :get,
      { hasFeature: 1, nodes: ["pve1", "pve2"] },
      [],
      params: { feature: "clone" }
    )

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.feature_available?(100, "pve1", "clone")

    assert_equal({ available: true, nodes: ["pve1", "pve2"] }, result)
    mock_client.verify
    mock_endpoint.verify
  end

  def test_feature_available_includes_snapname_when_provided
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/feature"])
    mock_endpoint.expect(
      :get,
      { hasFeature: 1, nodes: [] },
      [],
      params: { feature: "snapshot", snapname: "snap1" }
    )

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.feature_available?(100, "pve1", "snapshot", snapname: "snap1")

    mock_endpoint.verify
  end

  def test_feature_available_omits_snapname_when_nil
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/feature"])
    # snapname must NOT be in params at all when nil
    mock_endpoint.expect(
      :get,
      { hasFeature: 0, nodes: [] },
      [],
      params: { feature: "copy" }
    )

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    repo.feature_available?(100, "pve1", "copy", snapname: nil)

    mock_endpoint.verify
  end

  def test_feature_available_returns_false_when_has_feature_zero
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/feature"])
    mock_endpoint.expect(
      :get,
      { hasFeature: 0, nodes: [] },
      [],
      params: { feature: "clone" }
    )

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.feature_available?(100, "pve1", "clone")

    assert_equal({ available: false, nodes: [] }, result)
  end

  def test_feature_available_defaults_nodes_to_empty_array
    mock_client = Minitest::Mock.new
    mock_endpoint = Minitest::Mock.new

    mock_client.expect(:[], mock_endpoint, ["nodes/pve1/qemu/100/feature"])
    # LXC variant returns only hasFeature (no nodes key)
    mock_endpoint.expect(
      :get,
      { hasFeature: 1 },
      [],
      params: { feature: "clone" }
    )

    connection = Minitest::Mock.new
    connection.expect(:client, mock_client)

    repo = Pvectl::Repositories::Vm.new(connection)
    result = repo.feature_available?(100, "pve1", "clone")

    assert_equal({ available: true, nodes: [] }, result)
  end
end
