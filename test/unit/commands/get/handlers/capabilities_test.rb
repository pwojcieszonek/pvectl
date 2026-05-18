# frozen_string_literal: true

require "test_helper"

class GetHandlersCapabilitiesTest < Minitest::Test
  class MockCapabilitiesRepo
    def initialize(by_node: {}, error: nil)
      @by_node = by_node
      @error = error
    end

    def list(node:)
      raise @error if @error

      @by_node.fetch(node, [])
    end
  end

  class MockNodeRepo
    def initialize(nodes)
      @nodes = nodes
    end

    def list(**_kwargs)
      @nodes
    end

    def get(name, **_kwargs)
      @nodes.find { |n| n.name == name }
    end
  end

  def setup
    @pve1 = Pvectl::Models::Node.new(name: "pve1", status: "online")
    @pve2 = Pvectl::Models::Node.new(name: "pve2", status: "online")
    @pve3 = Pvectl::Models::Node.new(name: "pve3", status: "offline")

    @cpu_pve1 = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :cpu, name: "host", vendor: "Intel"
    )
    @machine_pve1 = Pvectl::Models::Capability.new(
      node_name: "pve1", kind: :machine, name: "pc-q35-8.1",
      machine_type: "q35", version: "8.1"
    )
    @cpu_pve2 = Pvectl::Models::Capability.new(
      node_name: "pve2", kind: :cpu, name: "kvm64", vendor: "Intel"
    )
  end

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Capabilities
  end

  def test_includes_resource_handler
    handler = build_handler(by_node: { "pve1" => [@cpu_pve1] }, nodes: [@pve1])
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
  end

  def test_list_with_node_returns_only_that_nodes_capabilities
    handler = build_handler(
      by_node: { "pve1" => [@cpu_pve1, @machine_pve1], "pve2" => [@cpu_pve2] },
      nodes: [@pve1, @pve2]
    )

    caps = handler.list(node: "pve1")

    assert_equal 2, caps.length
    assert(caps.all? { |c| c.node_name == "pve1" })
  end

  def test_list_with_unknown_node_raises_not_found
    handler = build_handler(by_node: {}, nodes: [@pve1])

    assert_raises Pvectl::ResourceNotFoundError do
      handler.list(node: "bogus")
    end
  end

  def test_list_without_node_iterates_online_nodes
    handler = build_handler(
      by_node: { "pve1" => [@cpu_pve1], "pve2" => [@cpu_pve2] },
      nodes: [@pve1, @pve2, @pve3]
    )

    caps = handler.list

    assert_equal 2, caps.length
    names = caps.map(&:node_name).sort
    assert_equal ["pve1", "pve2"], names
  end

  def test_list_skips_unreachable_nodes_silently
    cpu_pve1 = @cpu_pve1
    repo = MockCapabilitiesRepo.new(by_node: {})
    repo.define_singleton_method(:list) do |node:|
      raise StandardError, "timeout" if node == "pve2"

      node == "pve1" ? [cpu_pve1] : []
    end
    node_repo = MockNodeRepo.new([@pve1, @pve2])

    handler = Pvectl::Commands::Get::Handlers::Capabilities.new(
      repository: repo, node_repository: node_repo
    )

    caps = handler.list

    assert_equal 1, caps.length
    assert_equal "pve1", caps.first.node_name
  end

  def test_presenter_returns_capability_presenter
    handler = build_handler(by_node: { "pve1" => [@cpu_pve1] }, nodes: [@pve1])
    assert_kind_of Pvectl::Presenters::Capability, handler.presenter
  end

  private

  def build_handler(by_node:, nodes:)
    Pvectl::Commands::Get::Handlers::Capabilities.new(
      repository: MockCapabilitiesRepo.new(by_node: by_node),
      node_repository: MockNodeRepo.new(nodes)
    )
  end
end
