# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::ResourceHandler Tests
# =============================================================================

class GetResourceHandlerTest < Minitest::Test
  # Tests for the resource handler interface module

  # ---------------------------
  # Module Existence
  # ---------------------------

  def test_resource_handler_module_exists
    assert_kind_of Module, Pvectl::Commands::Get::ResourceHandler
  end

  # ---------------------------
  # #list() Method (Interface Contract)
  # ---------------------------

  def test_list_raises_not_implemented_error_by_default
    handler = HandlerWithoutImplementation.new

    error = assert_raises(NotImplementedError) do
      handler.list
    end

    assert_includes error.message, "list must be implemented"
  end

  def test_list_raises_not_implemented_with_class_name
    handler = HandlerWithoutImplementation.new

    error = assert_raises(NotImplementedError) do
      handler.list(node: "pve1", name: "test")
    end

    assert_includes error.message, "HandlerWithoutImplementation"
  end

  def test_list_accepts_node_and_name_kwargs
    handler = CompleteHandler.new

    # Should not raise
    result = handler.list(node: "pve1", name: "test-vm")

    assert_kind_of Array, result
  end

  def test_list_with_nil_kwargs
    handler = CompleteHandler.new

    # Should not raise when kwargs are nil (default)
    result = handler.list(node: nil, name: nil)

    assert_kind_of Array, result
  end

  # ---------------------------
  # #presenter() Method (Interface Contract)
  # ---------------------------

  def test_presenter_raises_not_implemented_error_by_default
    handler = HandlerWithoutImplementation.new

    error = assert_raises(NotImplementedError) do
      handler.presenter
    end

    assert_includes error.message, "presenter must be implemented"
  end

  def test_presenter_raises_not_implemented_with_class_name
    handler = HandlerWithoutImplementation.new

    error = assert_raises(NotImplementedError) do
      handler.presenter
    end

    assert_includes error.message, "HandlerWithoutImplementation"
  end

  def test_presenter_returns_presenter_instance_when_implemented
    handler = CompleteHandler.new

    presenter = handler.presenter

    assert_kind_of Pvectl::Presenters::Base, presenter
  end

  # ---------------------------
  # Complete Implementation Tests
  # ---------------------------

  def test_complete_handler_implements_all_required_methods
    handler = CompleteHandler.new

    # Both methods should work without raising
    assert_respond_to handler, :list
    assert_respond_to handler, :presenter

    list_result = handler.list
    assert_kind_of Array, list_result

    presenter_result = handler.presenter
    refute_nil presenter_result
  end

  def test_handler_can_filter_by_node
    handler = FilteringHandler.new

    all_results = handler.list
    filtered_results = handler.list(node: "pve1")

    assert all_results.length > filtered_results.length
    assert filtered_results.all? { |item| item[:node] == "pve1" }
  end

  def test_handler_can_filter_by_name
    handler = FilteringHandler.new

    all_results = handler.list
    filtered_results = handler.list(name: "vm-100")

    assert all_results.length > filtered_results.length
    assert filtered_results.all? { |item| item[:name] == "vm-100" }
  end

  def test_handler_can_filter_by_both_node_and_name
    handler = FilteringHandler.new

    filtered_results = handler.list(node: "pve1", name: "vm-100")

    assert_equal 1, filtered_results.length
    assert_equal "pve1", filtered_results.first[:node]
    assert_equal "vm-100", filtered_results.first[:name]
  end

  private

  # Handler that doesn't implement required methods
  class HandlerWithoutImplementation
    include Pvectl::Commands::Get::ResourceHandler
  end

  # Handler that implements all required methods
  class CompleteHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      []
    end

    def presenter
      TestPresenter.new
    end
  end

  # Handler with filtering logic
  class FilteringHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      results = [
        { node: "pve1", name: "vm-100" },
        { node: "pve1", name: "vm-101" },
        { node: "pve2", name: "vm-200" },
        { node: "pve2", name: "vm-201" }
      ]

      results = results.select { |r| r[:node] == node } if node
      results = results.select { |r| r[:name] == name } if name

      results
    end

    def presenter
      TestPresenter.new
    end
  end

  # Simple test presenter
  class TestPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "NODE"]
    end

    def to_row(model, **_context)
      [model[:name], model[:node]]
    end

    def to_hash(model)
      { "name" => model[:name], "node" => model[:node] }
    end
  end
end
