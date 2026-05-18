# frozen_string_literal: true

require "test_helper"

class GetHandlersSubscriptionTest < Minitest::Test
  def setup
    @active = Pvectl::Models::Subscription.new(node: "pve1", status: "active", level: "c", key: "pve1c-1234567890")
    @missing = Pvectl::Models::Subscription.new(node: "pve2", status: "notfound")
    @all = [@active, @missing]
  end

  def test_handler_responds_to_resource_handler_interface
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new(@all))

    assert_respond_to handler, :list
    assert_respond_to handler, :presenter
    assert_respond_to handler, :describe
  end

  def test_list_returns_all_records_from_repository
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new(@all))

    records = handler.list

    assert_equal 2, records.length
  end

  def test_list_forwards_node_filter_to_repository
    repo = MockRepo.new(@all)
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: repo)

    handler.list(node: "pve1")

    assert_equal "pve1", repo.last_node_filter
  end

  def test_presenter_returns_subscription_presenter
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new([]))

    assert_instance_of Pvectl::Presenters::Subscription, handler.presenter
  end

  def test_describe_returns_record_for_named_node
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new(@all))

    record = handler.describe(name: "pve1")

    assert_instance_of Pvectl::Models::Subscription, record
    assert_equal "pve1", record.node
  end

  def test_describe_raises_argument_error_for_empty_name
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new(@all))

    assert_raises ArgumentError do
      handler.describe(name: "")
    end
  end

  def test_describe_raises_resource_not_found_error_when_repo_returns_nil
    handler = Pvectl::Commands::Get::Handlers::Subscription.new(repository: MockRepo.new([]))

    error = assert_raises Pvectl::ResourceNotFoundError do
      handler.describe(name: "unknown")
    end

    assert_match(/Subscription not found/, error.message)
  end

  def test_handler_is_registered_for_subscription_and_aliases
    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register(
      "subscription",
      Pvectl::Commands::Get::Handlers::Subscription,
      aliases: ["subscriptions", "sub"]
    )

    assert Pvectl::Commands::Get::ResourceRegistry.registered?("subscription")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("subscriptions")
    assert Pvectl::Commands::Get::ResourceRegistry.registered?("sub")
  end

  class MockRepo
    attr_reader :last_node_filter

    def initialize(records)
      @records = records
    end

    def list(node: nil)
      @last_node_filter = node
      node ? @records.select { |r| r.node == node } : @records
    end

    def get(name)
      @records.find { |r| r.node == name }
    end
  end
end
