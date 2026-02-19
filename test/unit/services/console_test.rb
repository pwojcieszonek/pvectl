# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/pvectl/services/console"

class ServicesConsoleTest < Minitest::Test
  def test_class_exists
    assert_kind_of Class, Pvectl::Services::Console
  end

  def test_authenticate_posts_to_access_ticket
    response_body = {
      data: { ticket: "PVE:root@pam:abc123", CSRFPreventionToken: "csrf-token" }
    }.to_json

    mock_response = Minitest::Mock.new
    mock_response.expect(:body, response_body)

    mock_endpoint = Minitest::Mock.new
    mock_endpoint.expect(:post, mock_response) do |params|
      params == { username: "root@pam", password: "secret" }
    end

    mock_client = Minitest::Mock.new
    mock_client.expect(:[], mock_endpoint, ["access/ticket"])

    service = Pvectl::Services::Console.new

    result = RestClient::Resource.stub(:new, mock_client) do
      service.send(:authenticate_with_client, mock_client, "root@pam", "secret")
    end

    assert_equal "PVE:root@pam:abc123", result[:ticket]
    assert_equal "csrf-token", result[:csrf_token]
    mock_endpoint.verify
  end

  def test_build_websocket_url_constructs_correct_url
    service = Pvectl::Services::Console.new
    url = service.build_websocket_url(
      server: "https://pve1.example.com:8006",
      node: "pve1",
      resource_path: "qemu/100",
      port: 5900,
      ticket: "PVEVNC:abc123"
    )

    assert_match %r{wss://pve1\.example\.com:8006/api2/json/nodes/pve1/qemu/100/vncwebsocket}, url
    assert_match(/port=5900/, url)
    assert_match(/vncticket=PVEVNC/, url)
  end

  def test_build_websocket_url_url_encodes_ticket
    service = Pvectl::Services::Console.new
    url = service.build_websocket_url(
      server: "https://pve1:8006",
      node: "pve1",
      resource_path: "qemu/100",
      port: 5900,
      ticket: "PVEVNC:abc:with:colons"
    )

    # Colons in ticket should be URL-encoded
    assert_match(/vncticket=PVEVNC%3Aabc%3Awith%3Acolons/, url)
  end

  def test_validate_resource_running_raises_for_stopped_vm
    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", status: "stopped", node: "pve1")

    service = Pvectl::Services::Console.new
    error = assert_raises(Pvectl::Services::Console::ResourceNotRunningError) do
      service.validate_resource_running!(vm)
    end

    assert_match(/not running/, error.message)
  end

  def test_validate_resource_running_passes_for_running_vm
    vm = Pvectl::Models::Vm.new(vmid: 100, name: "test", status: "running", node: "pve1")

    service = Pvectl::Services::Console.new
    # Should not raise
    service.validate_resource_running!(vm)
  end
end
