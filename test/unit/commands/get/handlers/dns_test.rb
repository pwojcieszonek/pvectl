# frozen_string_literal: true

require "test_helper"

class GetHandlersDnsTest < Minitest::Test
  class MockDnsRepository
    def initialize(configs)
      @configs = configs
    end

    def fetch(node_name)
      @configs[node_name] || raise(StandardError, "node #{node_name} not found")
    end
  end

  def setup
    @dns_pve1 = Pvectl::Models::DnsConfig.new(
      node: "pve1", search: "example.com", dns1: "8.8.8.8", dns2: "1.1.1.1"
    )
  end

  def test_handler_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Handlers::Dns
  end

  def test_handler_implements_resource_handler
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: MockDnsRepository.new({}))
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
    assert_respond_to handler, :describe
  end

  def test_list_with_node_returns_dns_config_in_array
    repo = MockDnsRepository.new("pve1" => @dns_pve1)
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: repo)

    result = handler.list(node: "pve1")

    assert_kind_of Array, result
    assert_equal 1, result.length
    assert_instance_of Pvectl::Models::DnsConfig, result.first
    assert_equal "pve1", result.first.node
  end

  def test_list_without_node_raises_argument_error
    repo = MockDnsRepository.new("pve1" => @dns_pve1)
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: repo)

    assert_raises ArgumentError do
      handler.list
    end
  end

  def test_presenter_returns_dns_config_presenter
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: MockDnsRepository.new({}))

    assert_instance_of Pvectl::Presenters::DnsConfig, handler.presenter
  end

  def test_describe_returns_dns_config
    repo = MockDnsRepository.new("pve1" => @dns_pve1)
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: repo)

    result = handler.describe(name: "pve1")

    assert_instance_of Pvectl::Models::DnsConfig, result
    assert_equal "pve1", result.node
  end

  def test_describe_uses_node_option_when_no_name
    repo = MockDnsRepository.new("pve1" => @dns_pve1)
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: repo)

    result = handler.describe(name: nil, node: "pve1")

    assert_instance_of Pvectl::Models::DnsConfig, result
  end

  def test_describe_raises_when_no_node_or_name
    handler = Pvectl::Commands::Get::Handlers::Dns.new(repository: MockDnsRepository.new({}))

    assert_raises ArgumentError do
      handler.describe(name: nil)
    end
  end

  def test_handler_is_registered_for_dns
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "dns", Pvectl::Commands::Get::Handlers::Dns
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("dns")
  end
end
