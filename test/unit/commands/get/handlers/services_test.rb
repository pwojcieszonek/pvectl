# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Handlers::Services Tests
# =============================================================================

class GetHandlersServicesTest < Minitest::Test
  def setup
    @s1 = Pvectl::Models::Service.new(
      service: "pveproxy", name: "pveproxy", state: "running",
      desc: "PVE API Proxy Server", active_state: "active",
      unit_state: "enabled", node: "pve1"
    )
    @s2 = Pvectl::Models::Service.new(
      service: "corosync", name: "corosync", state: "running",
      desc: "Corosync Cluster Engine", active_state: "active",
      unit_state: "enabled", node: "pve1"
    )
    @s3 = Pvectl::Models::Service.new(
      service: "pveproxy", name: "pveproxy", state: "running",
      desc: "PVE API Proxy Server", active_state: "active",
      unit_state: "enabled", node: "pve2"
    )
    @all = [@s1, @s2, @s3]
  end

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Services
  end

  def test_handler_includes_resource_handler
    handler = build_handler(@all)
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  def test_list_returns_all_services
    handler = build_handler(@all)
    assert_equal 3, handler.list.size
  end

  def test_list_with_node_filter
    handler = build_handler(@all)
    services = handler.list(node: "pve1")
    assert_equal 2, services.size
    assert services.all? { |s| s.node == "pve1" }
  end

  def test_list_with_name_filter_matches_service
    handler = build_handler(@all)
    services = handler.list(name: "pveproxy")
    assert_equal 2, services.size
    assert services.all? { |s| s.service == "pveproxy" }
  end

  def test_list_returns_empty_when_no_match
    handler = build_handler(@all)
    assert_empty handler.list(name: "nonexistent")
  end

  def test_presenter_returns_service_presenter
    handler = build_handler([])
    assert_instance_of Pvectl::Presenters::Service, handler.presenter
  end

  def test_handler_registered_with_services_alias
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "services", Pvectl::Commands::Get::Handlers::Services, aliases: ["svc"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("services")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("svc")
  end

  private

  def build_handler(services)
    Pvectl::Commands::Get::Handlers::Services.new(repository: MockSvcRepo.new(services))
  end

  class MockSvcRepo
    def initialize(services)
      @services = services
    end

    def list(node: nil)
      if node
        @services.select { |s| s.node == node }
      else
        @services.dup
      end
    end
  end
end
