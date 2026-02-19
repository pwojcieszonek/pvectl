# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Describe::Command Tests - Basic Structure
# =============================================================================

class DescribeCommandBasicTest < Minitest::Test
  # Tests for basic command structure and class existence

  def test_command_class_exists
    assert_kind_of Class, Pvectl::Commands::Describe::Command
  end

  def test_execute_class_method_exists
    assert_respond_to Pvectl::Commands::Describe::Command, :execute
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Missing Arguments
# =============================================================================

class DescribeCommandMissingArgumentsTest < Minitest::Test
  # Tests for missing argument error handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_returns_usage_error_when_resource_type_is_nil
    exit_code = Pvectl::Commands::Describe::Command.execute(nil, nil, {}, {})

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_message_when_resource_type_is_nil
    Pvectl::Commands::Describe::Command.execute(nil, nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Error: resource type is required"
  end

  def test_outputs_usage_hint_when_resource_type_is_nil
    Pvectl::Commands::Describe::Command.execute(nil, nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Usage: pvectl describe RESOURCE_TYPE NAME"
  end

  def test_returns_usage_error_when_resource_name_is_nil
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", MockDescribeHandler)

    exit_code = Pvectl::Commands::Describe::Command.execute("node", nil, {}, {})

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_message_when_resource_name_is_nil
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", MockDescribeHandler)

    Pvectl::Commands::Describe::Command.execute("node", nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Error: resource name is required"
  end

  def test_outputs_usage_hint_with_resource_type_when_name_is_nil
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", MockDescribeHandler)

    Pvectl::Commands::Describe::Command.execute("node", nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Usage: pvectl describe node NAME"
  end

  private

  class MockDescribeHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil)
      []
    end

    def describe(name:, node: nil)
      nil
    end

    def presenter
      MockPresenter.new
    end
  end

  class MockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Unknown Resource Type
# =============================================================================

class DescribeCommandUnknownResourceTypeTest < Minitest::Test
  # Tests for unknown resource type error handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_returns_usage_error_for_unknown_resource_type
    exit_code = Pvectl::Commands::Describe::Command.execute("unknown", "name", {}, {})

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_unknown_resource_type_message
    Pvectl::Commands::Describe::Command.execute("xyz", "name", {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Unknown resource type: xyz"
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Resource Not Found
# =============================================================================

class DescribeCommandNotFoundTest < Minitest::Test
  # Tests for resource not found error handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_returns_not_found_when_resource_does_not_exist
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", NotFoundHandler, aliases: ["node"])

    exit_code = Pvectl::Commands::Describe::Command.execute(
      "node",
      "nonexistent",
      {},
      { output: "table" }
    )

    assert_equal Pvectl::ExitCodes::NOT_FOUND, exit_code
  end

  def test_outputs_not_found_message
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", NotFoundHandler, aliases: ["node"])

    Pvectl::Commands::Describe::Command.execute(
      "node",
      "nonexistent",
      {},
      { output: "table" }
    )

    stderr_output = $stderr.string
    assert_includes stderr_output, "Node not found: nonexistent"
  end

  private

  class NotFoundHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil)
      []
    end

    def describe(name:, node: nil)
      raise Pvectl::ResourceNotFoundError, "Node not found: #{name}"
    end

    def presenter
      MockPresenter.new
    end
  end

  class MockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Successful Execution
# =============================================================================

class DescribeCommandSuccessTest < Minitest::Test
  # Tests for successful describe execution

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", SuccessHandler, aliases: ["node"])
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_returns_success_for_valid_resource
    exit_code = Pvectl::Commands::Describe::Command.execute(
      "node",
      "pve-node1",
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_outputs_to_stdout
    Pvectl::Commands::Describe::Command.execute(
      "node",
      "pve-node1",
      {},
      { output: "json" }
    )

    stdout_output = $stdout.string
    refute_empty stdout_output
  end

  def test_outputs_json_when_format_is_json
    Pvectl::Commands::Describe::Command.execute(
      "node",
      "pve-node1",
      {},
      { output: "json" }
    )

    stdout_output = $stdout.string
    parsed = JSON.parse(stdout_output)
    assert_equal "pve-node1", parsed["name"]
    assert_equal "online", parsed["status"]
  end

  def test_outputs_yaml_when_format_is_yaml
    Pvectl::Commands::Describe::Command.execute(
      "node",
      "pve-node1",
      {},
      { output: "yaml" }
    )

    stdout_output = $stdout.string
    parsed = YAML.safe_load(stdout_output)
    assert_equal "pve-node1", parsed["name"]
    assert_equal "online", parsed["status"]
  end

  def test_outputs_table_format_by_default
    Pvectl::Commands::Describe::Command.execute(
      "node",
      "pve-node1",
      {},
      {}
    )

    stdout_output = $stdout.string
    # Table format should have key-value pairs
    assert_includes stdout_output, "Name:"
    assert_includes stdout_output, "pve-node1"
  end

  def test_routes_via_alias
    exit_code = Pvectl::Commands::Describe::Command.execute(
      "nodes",
      "pve-node1",
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  private

  class SuccessHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil)
      [MockNode.new("pve-node1", "online")]
    end

    def describe(name:, node: nil)
      MockNode.new(name, "online")
    end

    def presenter
      MockNodePresenter.new
    end
  end

  class MockNode
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  class MockNodePresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Connection Errors
# =============================================================================

class DescribeCommandConnectionErrorTest < Minitest::Test
  # Tests for connection error handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_handles_timeout_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def describe(name:, node: nil)
        raise Timeout::Error, "Connection timed out"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("timeout", handler_class)

    exit_code = Pvectl::Commands::Describe::Command.execute(
      "timeout",
      "test",
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_handles_connection_refused_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def describe(name:, node: nil)
        raise Errno::ECONNREFUSED, "Connection refused"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("connrefused", handler_class)

    exit_code = Pvectl::Commands::Describe::Command.execute(
      "connrefused",
      "test",
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_handles_socket_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def describe(name:, node: nil)
        raise SocketError, "getaddrinfo: Name or service not known"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("socketerr", handler_class)

    exit_code = Pvectl::Commands::Describe::Command.execute(
      "socketerr",
      "test",
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_outputs_error_message_to_stderr
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def describe(name:, node: nil)
        raise Timeout::Error, "Connection timed out"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("errmsg", handler_class)

    Pvectl::Commands::Describe::Command.execute(
      "errmsg",
      "test",
      {},
      { output: "table" }
    )

    stderr_output = $stderr.string
    assert_includes stderr_output.downcase, "error"
  end

  private

  class MockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end

# =============================================================================
# Commands::Describe::Command Tests - Color Support
# =============================================================================

class DescribeCommandColorSupportTest < Minitest::Test
  # Tests for color output handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("test", MockColorHandler)
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_respects_color_flag_false
    Pvectl::Commands::Describe::Command.execute(
      "test",
      "item",
      {},
      { output: "table", color: false }
    )

    stdout_output = $stdout.string
    refute_match(/\e\[/, stdout_output, "Output should not contain ANSI codes with color: false")
  end

  private

  class MockColorHandler
    include Pvectl::Commands::Get::ResourceHandler

    def describe(name:, node: nil)
      MockModel.new(name, "running")
    end

    def presenter
      MockPresenter.new
    end
  end

  class MockModel
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  class MockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end

    def to_description(model)
      to_hash(model)
    end
  end
end
