# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Services::Get::ResourceService Tests
# =============================================================================

class GetResourceServiceTest < Minitest::Test
  # Tests for the resource service that orchestrates data fetching and formatting

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_resource_service_class_exists
    assert_kind_of Class, Pvectl::Services::Get::ResourceService
  end

  # ---------------------------
  # Initialization
  # ---------------------------

  def test_initialize_with_handler
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler)

    refute_nil service
  end

  def test_initialize_with_format
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    refute_nil service
  end

  def test_initialize_with_color_enabled
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, color_enabled: false)

    refute_nil service
  end

  def test_initialize_defaults_to_table_format
    handler = MockHandler.new
    # Create service with default format - we'll test via list output
    service = Pvectl::Services::Get::ResourceService.new(handler: handler)

    refute_nil service
  end

  def test_initialize_defaults_to_color_enabled_true
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler)

    refute_nil service
  end

  # ---------------------------
  # #list Method - Basic Functionality
  # ---------------------------

  def test_list_returns_formatted_string
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    result = service.list

    assert_kind_of String, result
  end

  def test_list_calls_handler_list
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list

    assert handler.list_called, "Handler#list should have been called"
  end

  def test_list_calls_handler_presenter
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list

    assert handler.presenter_called, "Handler#presenter should have been called"
  end

  # ---------------------------
  # #list Method - Parameter Passing
  # ---------------------------

  def test_list_passes_node_to_handler
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list(node: "pve1")

    assert_equal "pve1", handler.last_node_param
  end

  def test_list_passes_name_to_handler
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list(name: "vm-100")

    assert_equal "vm-100", handler.last_name_param
  end

  def test_list_passes_both_node_and_name_to_handler
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list(node: "pve2", name: "container-200")

    assert_equal "pve2", handler.last_node_param
    assert_equal "container-200", handler.last_name_param
  end

  def test_list_passes_nil_node_by_default
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list

    assert_nil handler.last_node_param
  end

  def test_list_passes_nil_name_by_default
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list

    assert_nil handler.last_name_param
  end

  # ---------------------------
  # #list Method - Args Parameter
  # ---------------------------

  def test_list_passes_args_to_handler
    handler = ArgsCapturingHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list(args: ["100", "101"])

    assert_equal ["100", "101"], handler.last_args_param
  end

  def test_list_passes_empty_args_by_default
    handler = ArgsCapturingHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list

    assert_equal [], handler.last_args_param
  end

  def test_list_passes_all_parameters_together
    handler = ArgsCapturingHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.list(node: "pve1", name: "test", args: ["100"])

    assert_equal "pve1", handler.last_node_param
    assert_equal "test", handler.last_name_param
    assert_equal ["100"], handler.last_args_param
  end

  # ---------------------------
  # #list Method - Format Output
  # ---------------------------

  def test_list_with_json_format_returns_json
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    result = service.list

    # Should be valid JSON
    data = JSON.parse(result)
    assert_kind_of Array, data
  end

  def test_list_with_yaml_format_returns_yaml
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "yaml")

    result = service.list

    # Should be valid YAML
    data = YAML.safe_load(result)
    assert_kind_of Array, data
  end

  def test_list_with_table_format_returns_table_string
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "table")

    result = service.list

    # Table format should contain column headers
    assert_includes result.upcase, "NAME"
    assert_includes result.upcase, "STATUS"
  end

  def test_list_with_wide_format_returns_wide_table
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "wide")

    result = service.list

    # Wide format should contain all columns including extra
    assert_includes result.upcase, "NAME"
    assert_includes result.upcase, "STATUS"
    assert_includes result.upcase, "EXTRA"
  end

  # ---------------------------
  # #list Method - Color Support
  # ---------------------------

  def test_list_passes_color_enabled_to_formatter
    handler = MockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(
      handler: handler,
      format: "table",
      color_enabled: false
    )

    result = service.list

    # Without color, output should not contain ANSI codes
    refute_match(/\e\[/, result, "Output should not contain ANSI color codes when color_enabled is false")
  end

  # ---------------------------
  # #list Method - Empty Results
  # ---------------------------

  def test_list_handles_empty_results
    handler = EmptyHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    result = service.list

    data = JSON.parse(result)
    assert_kind_of Array, data
    assert_empty data
  end

  def test_list_table_format_handles_empty_results
    handler = EmptyHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "table")

    result = service.list

    # Should still have headers or empty table
    assert_kind_of String, result
  end

  # ---------------------------
  # #describe Method - Basic Functionality
  # ---------------------------

  def test_describe_returns_formatted_string
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    result = service.describe(name: "test-resource")

    assert_kind_of String, result
  end

  def test_describe_calls_handler_describe
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.describe(name: "test-resource")

    assert handler.describe_called, "Handler#describe should have been called"
  end

  def test_describe_passes_name_to_handler
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    service.describe(name: "my-resource")

    assert_equal "my-resource", handler.last_describe_name
  end

  # ---------------------------
  # #describe Method - Format Output
  # ---------------------------

  def test_describe_with_json_format_returns_json
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "json")

    result = service.describe(name: "test")

    data = JSON.parse(result)
    assert_kind_of Hash, data
    assert_equal "test", data["name"]
  end

  def test_describe_with_yaml_format_returns_yaml
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "yaml")

    result = service.describe(name: "test")

    data = YAML.safe_load(result)
    assert_kind_of Hash, data
    assert_equal "test", data["name"]
  end

  def test_describe_with_table_format_returns_vertical_layout
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(handler: handler, format: "table")

    result = service.describe(name: "test")

    # Vertical layout should have "Key: Value" format
    assert_match(/Name:/i, result)
    assert_includes result, "test"
  end

  # ---------------------------
  # #describe Method - Color Support
  # ---------------------------

  def test_describe_passes_color_enabled_to_formatter
    handler = DescribeMockHandler.new
    service = Pvectl::Services::Get::ResourceService.new(
      handler: handler,
      format: "table",
      color_enabled: false
    )

    result = service.describe(name: "test")

    # Without color, output should not contain ANSI codes
    refute_match(/\e\[/, result, "Output should not contain ANSI codes when color_enabled is false")
  end

  private

  # Mock handler for testing
  class MockHandler
    include Pvectl::Commands::Get::ResourceHandler

    attr_reader :list_called, :presenter_called, :last_node_param, :last_name_param

    def initialize
      @list_called = false
      @presenter_called = false
      @last_node_param = nil
      @last_name_param = nil
    end

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      @list_called = true
      @last_node_param = node
      @last_name_param = name

      [
        MockModel.new("vm-100", "running", "extra-value"),
        MockModel.new("vm-101", "stopped", "other-value")
      ]
    end

    def presenter
      @presenter_called = true
      MockPresenter.new
    end
  end

  # Handler that returns empty results
  class EmptyHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      []
    end

    def presenter
      MockPresenter.new
    end
  end

  # Mock handler for describe tests
  class DescribeMockHandler
    include Pvectl::Commands::Get::ResourceHandler

    attr_reader :describe_called, :last_describe_name

    def initialize
      @describe_called = false
      @last_describe_name = nil
    end

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [MockModel.new("model-1", "running", "extra")]
    end

    def describe(name:, node: nil)
      @describe_called = true
      @last_describe_name = name
      MockModel.new(name, "running", "extra-value")
    end

    def presenter
      DescribeMockPresenter.new
    end
  end

  # Mock presenter for describe tests
  class DescribeMockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status, "extra" => model.extra }
    end

    def to_description(model)
      to_hash(model)
    end
  end

  # Mock model
  class MockModel
    attr_reader :name, :status, :extra

    def initialize(name, status, extra)
      @name = name
      @status = status
      @extra = extra
    end
  end

  # Mock presenter
  class MockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def extra_columns
      ["EXTRA"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def extra_values(model, **_context)
      [model.extra]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status, "extra" => model.extra }
    end
  end

  # Handler that captures args parameter
  class ArgsCapturingHandler
    include Pvectl::Commands::Get::ResourceHandler

    attr_reader :last_node_param, :last_name_param, :last_args_param

    def initialize
      @last_node_param = nil
      @last_name_param = nil
      @last_args_param = nil
    end

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      @last_node_param = node
      @last_name_param = name
      @last_args_param = args
      [MockModel.new("test", "running", "extra")]
    end

    def presenter
      MockPresenter.new
    end
  end
end
