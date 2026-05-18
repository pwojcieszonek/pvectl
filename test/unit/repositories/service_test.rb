# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Service Tests
# =============================================================================

class RepositoriesServiceTest < Minitest::Test
  def setup
    @services_response = [
      {
        service: "pveproxy",
        name: "pveproxy",
        state: "running",
        desc: "PVE API Proxy Server",
        :"active-state" => "active",
        :"unit-state" => "enabled"
      },
      {
        service: "corosync",
        name: "corosync",
        state: "running",
        desc: "Corosync Cluster Engine",
        :"active-state" => "active",
        :"unit-state" => "enabled"
      }
    ]

    @nodes_response = [
      { node: "pve1", status: "online" },
      { node: "pve2", status: "online" },
      { node: "pve3", status: "offline" }
    ]
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Repositories::Service
  end

  def test_inherits_from_base
    assert Pvectl::Repositories::Service < Pvectl::Repositories::Base
  end

  def test_list_returns_service_models_for_node
    repo = build_repo(services: { "pve1" => @services_response }, nodes: @nodes_response)

    services = repo.list(node: "pve1")

    assert_equal 2, services.size
    assert services.all? { |s| s.is_a?(Pvectl::Models::Service) }
  end

  def test_list_sets_node_on_models
    repo = build_repo(services: { "pve1" => @services_response }, nodes: @nodes_response)

    services = repo.list(node: "pve1")

    assert services.all? { |s| s.node == "pve1" }
  end

  def test_list_maps_dasherized_keys_to_attributes
    repo = build_repo(services: { "pve1" => @services_response }, nodes: @nodes_response)

    svc = repo.list(node: "pve1").first

    assert_equal "pveproxy", svc.service
    assert_equal "running", svc.state
    assert_equal "active", svc.active_state
    assert_equal "enabled", svc.unit_state
  end

  def test_list_without_node_iterates_online_nodes
    repo = build_repo(
      services: {
        "pve1" => [@services_response.first],
        "pve2" => [@services_response.last]
      },
      nodes: @nodes_response
    )

    services = repo.list

    assert_equal 2, services.size
    assert_equal %w[pve1 pve2], services.map(&:node)
  end

  def test_list_skips_offline_nodes
    repo = build_repo(services: { "pve1" => @services_response }, nodes: @nodes_response)

    services = repo.list

    refute services.any? { |s| s.node == "pve3" }
  end

  def test_list_handles_api_error_gracefully
    repo = build_repo(
      services: { "pve1" => StandardError.new("API down") },
      nodes: @nodes_response
    )

    assert_empty repo.list(node: "pve1")
  end

  def test_state_returns_service_model
    state_data = {
      service: "pveproxy",
      state: "running",
      :"active-state" => "active",
      :"unit-state" => "enabled"
    }
    repo = build_repo(services: {}, nodes: @nodes_response, state: { "pve1" => { "pveproxy" => state_data } })

    svc = repo.state("pve1", "pveproxy")

    assert_instance_of Pvectl::Models::Service, svc
    assert_equal "pveproxy", svc.service
    assert_equal "active", svc.active_state
    assert_equal "pve1", svc.node
  end

  def test_start_hits_start_endpoint
    repo = build_repo(services: {}, nodes: @nodes_response, posts: {})

    upid = repo.start("pve1", "pveproxy")

    assert_equal "UPID:pve1:start:pveproxy", upid
  end

  def test_stop_hits_stop_endpoint
    repo = build_repo(services: {}, nodes: @nodes_response, posts: {})

    assert_equal "UPID:pve1:stop:pveproxy", repo.stop("pve1", "pveproxy")
  end

  def test_restart_hits_restart_endpoint
    repo = build_repo(services: {}, nodes: @nodes_response, posts: {})

    assert_equal "UPID:pve1:restart:pveproxy", repo.restart("pve1", "pveproxy")
  end

  def test_reload_hits_reload_endpoint
    repo = build_repo(services: {}, nodes: @nodes_response, posts: {})

    assert_equal "UPID:pve1:reload:pveproxy", repo.reload("pve1", "pveproxy")
  end

  private

  def build_repo(services:, nodes:, state: {}, posts: {})
    connection = MockSvcConnection.new(services: services, nodes: nodes, state: state, posts: posts)
    Pvectl::Repositories::Service.new(connection)
  end

  class MockSvcConnection
    def initialize(services:, nodes:, state: {}, posts: {})
      @services = services
      @nodes = nodes
      @state = state
      @posts = posts
    end

    def client
      @client ||= MockClient.new(services: @services, nodes: @nodes, state: @state, posts: @posts)
    end
  end

  class MockClient
    def initialize(services:, nodes:, state:, posts:)
      @services = services
      @nodes = nodes
      @state = state
      @posts = posts
    end

    def [](path)
      MockEndpoint.new(path, services: @services, nodes: @nodes, state: @state, posts: @posts)
    end
  end

  class MockEndpoint
    def initialize(path, services:, nodes:, state:, posts:)
      @path = path
      @services = services
      @nodes = nodes
      @state = state
      @posts = posts
    end

    def get(**_kwargs)
      case @path
      when "nodes"
        @nodes
      when %r{\Anodes/([^/]+)/services\z}
        node_name = Regexp.last_match(1)
        result = @services[node_name]
        raise result if result.is_a?(StandardError)

        result || []
      when %r{\Anodes/([^/]+)/services/([^/]+)/state\z}
        node, service = Regexp.last_match(1), Regexp.last_match(2)
        @state.dig(node, service)
      else
        []
      end
    end

    def post(_payload = nil, **_kwargs)
      case @path
      when %r{\Anodes/([^/]+)/services/([^/]+)/(start|stop|restart|reload)\z}
        node, service, action = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
        "UPID:#{node}:#{action}:#{service}"
      else
        ""
      end
    end
  end
end
