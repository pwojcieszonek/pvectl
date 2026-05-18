# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Repositories::Capabilities Tests
# =============================================================================

class RepositoriesCapabilitiesTest < Minitest::Test
  class MockClient
    def initialize(responses: {}, errors: {})
      @responses = responses
      @errors = errors
    end

    def [](path)
      raise @errors[path] if @errors.key?(path)

      MockResource.new(@responses[path])
    end
  end

  class MockResource
    def initialize(data)
      @data = data
    end

    def get(**_kwargs)
      @data
    end
  end

  class MockConnection
    def initialize(responses: {}, errors: {})
      @client = MockClient.new(responses: responses, errors: errors)
    end

    attr_reader :client
  end

  def setup
    @cpu_response = {
      data: [
        { name: "host", vendor: "GenuineIntel", custom: false },
        { name: "kvm64", vendor: "GenuineIntel", custom: false }
      ]
    }

    @machines_response = {
      data: [
        { id: "pc-q35-8.1", type: "q35", version: "8.1" },
        { id: "pc-i440fx-8.1", type: "i440fx", version: "8.1", changes: "fixed bug" }
      ]
    }
  end

  def test_class_exists
    assert_kind_of Class, Pvectl::Repositories::Capabilities
  end

  def test_inherits_from_base
    assert Pvectl::Repositories::Capabilities < Pvectl::Repositories::Base
  end

  def test_list_returns_cpu_and_machine_capabilities
    conn = MockConnection.new(responses: {
      "nodes/pve1/capabilities/qemu/cpu" => @cpu_response,
      "nodes/pve1/capabilities/qemu/machines" => @machines_response
    })

    repo = Pvectl::Repositories::Capabilities.new(conn)
    caps = repo.list(node: "pve1")

    assert_kind_of Array, caps
    assert_equal 4, caps.length
  end

  def test_list_models_cpu_capability_kind
    conn = MockConnection.new(responses: {
      "nodes/pve1/capabilities/qemu/cpu" => @cpu_response,
      "nodes/pve1/capabilities/qemu/machines" => @machines_response
    })

    cap = Pvectl::Repositories::Capabilities.new(conn).list(node: "pve1").first

    assert_kind_of Pvectl::Models::Capability, cap
    assert_equal :cpu, cap.kind
    assert_equal "pve1", cap.node_name
    assert_equal "host", cap.name
    assert_equal "GenuineIntel", cap.vendor
  end

  def test_list_models_machine_capability_kind
    conn = MockConnection.new(responses: {
      "nodes/pve1/capabilities/qemu/cpu" => { data: [] },
      "nodes/pve1/capabilities/qemu/machines" => @machines_response
    })

    machines = Pvectl::Repositories::Capabilities.new(conn).list(node: "pve1")

    assert_equal 2, machines.length
    assert_equal :machine, machines.first.kind
    assert_equal "pc-q35-8.1", machines.first.name
    assert_equal "q35", machines.first.machine_type
    assert_equal "8.1", machines.first.version
  end

  def test_list_handles_empty_responses
    conn = MockConnection.new(responses: {
      "nodes/pve1/capabilities/qemu/cpu" => { data: [] },
      "nodes/pve1/capabilities/qemu/machines" => { data: [] }
    })

    caps = Pvectl::Repositories::Capabilities.new(conn).list(node: "pve1")

    assert_empty caps
  end

  def test_list_handles_unwrapped_response
    conn = MockConnection.new(responses: {
      "nodes/pve1/capabilities/qemu/cpu" => [{ name: "host", vendor: "Intel" }],
      "nodes/pve1/capabilities/qemu/machines" => []
    })

    caps = Pvectl::Repositories::Capabilities.new(conn).list(node: "pve1")

    assert_equal 1, caps.length
    assert_equal "host", caps.first.name
  end

  def test_list_propagates_api_errors
    conn = MockConnection.new(errors: {
      "nodes/pve1/capabilities/qemu/cpu" => StandardError.new("403 Forbidden")
    })

    repo = Pvectl::Repositories::Capabilities.new(conn)

    assert_raises(StandardError) { repo.list(node: "pve1") }
  end
end
