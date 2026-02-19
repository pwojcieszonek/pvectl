# frozen_string_literal: true

require "test_helper"

class RepositoriesContainerCreateTest < Minitest::Test
  describe "Repositories::Container#create" do
    it "sends POST to /nodes/{node}/lxc with correct params" do
      mock_client = Minitest::Mock.new
      mock_endpoint = Minitest::Mock.new
      mock_connection = Minitest::Mock.new

      mock_connection.expect(:client, mock_client)
      mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc"])
      mock_endpoint.expect(:post, "UPID:pve1:create", [{ vmid: 200, hostname: "web-ct", ostemplate: "local:vztmpl/debian-12.tar.zst" }])

      repo = Pvectl::Repositories::Container.new(mock_connection)
      result = repo.create("pve1", 200, { hostname: "web-ct", ostemplate: "local:vztmpl/debian-12.tar.zst" })

      assert_equal "UPID:pve1:create", result
      mock_endpoint.verify
    end

    it "merges vmid into params" do
      mock_client = Minitest::Mock.new
      mock_endpoint = Minitest::Mock.new
      mock_connection = Minitest::Mock.new

      mock_connection.expect(:client, mock_client)
      mock_client.expect(:[], mock_endpoint, ["nodes/pve1/lxc"])
      mock_endpoint.expect(:post, "UPID:pve1:create", [{ vmid: 300 }])

      repo = Pvectl::Repositories::Container.new(mock_connection)
      repo.create("pve1", 300, {})

      mock_endpoint.verify
    end
  end
end
