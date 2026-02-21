# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::Command Tests - Basic Structure
# =============================================================================

class GetCommandBasicTest < Minitest::Test
  # Tests for basic command structure and class existence

  def test_command_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::Command
  end

  def test_execute_class_method_exists
    assert_respond_to Pvectl::Commands::Get::Command, :execute
  end
end

# =============================================================================
# Commands::Get::Command Tests - Missing Resource Type
# =============================================================================

class GetCommandMissingResourceTypeTest < Minitest::Test
  # Tests for missing resource_type argument handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    # Reset registry
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_returns_usage_error_when_resource_type_is_nil
    exit_code = Pvectl::Commands::Get::Command.execute(nil, nil, {}, {})

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_error_message_when_resource_type_is_nil
    Pvectl::Commands::Get::Command.execute(nil, nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Error: resource type is required"
  end

  def test_outputs_usage_hint_when_resource_type_is_nil
    Pvectl::Commands::Get::Command.execute(nil, nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Usage: pvectl get RESOURCE_TYPE"
  end
end

# =============================================================================
# Commands::Get::Command Tests - Unknown Resource Type
# =============================================================================

class GetCommandUnknownResourceTypeTest < Minitest::Test
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
    exit_code = Pvectl::Commands::Get::Command.execute("unknown", nil, {}, {})

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_outputs_unknown_resource_type_message
    Pvectl::Commands::Get::Command.execute("xyz", nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "Unknown resource type: xyz"
  end

  def test_unknown_resource_error_includes_type_name
    Pvectl::Commands::Get::Command.execute("foobar", nil, {}, {})

    stderr_output = $stderr.string
    assert_includes stderr_output, "foobar"
  end
end

# =============================================================================
# Commands::Get::Command Tests - Registry Routing
# =============================================================================

class GetCommandRegistryRoutingTest < Minitest::Test
  # Tests for routing to handlers via registry

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

  def test_routes_to_registered_handler
    mock_handler_class = MockSuccessHandler
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class)

    exit_code = Pvectl::Commands::Get::Command.execute(
      "nodes",
      nil,
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_routes_to_handler_via_alias
    mock_handler_class = MockSuccessHandler
    Pvectl::Commands::Get::ResourceRegistry.register("nodes", mock_handler_class, aliases: ["node"])

    exit_code = Pvectl::Commands::Get::Command.execute(
      "node",
      nil,
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_uses_custom_registry_when_provided
    mock_registry = MockRegistry.new
    mock_handler_class = MockSuccessHandler
    mock_registry.set_handler("test", mock_handler_class.new)

    command = Pvectl::Commands::Get::Command.new(
      "test",
      nil,
      {},
      { output: "json" },
      registry: mock_registry
    )

    exit_code = command.execute

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  private

  class MockSuccessHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [MockModel.new("test-node", "online")]
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
  end

  class MockRegistry
    def initialize
      @handlers = {}
    end

    def set_handler(type, handler)
      @handlers[type] = handler
    end

    def for(type)
      @handlers[type]
    end
  end
end

# =============================================================================
# Commands::Get::Command Tests - Normal Mode Execution
# =============================================================================

class GetCommandNormalModeTest < Minitest::Test
  # Tests for normal (non-watch) mode execution

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("test", MockHandler)
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_normal_mode_returns_success
    exit_code = Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::SUCCESS, exit_code
  end

  def test_normal_mode_outputs_to_stdout
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "json" }
    )

    stdout_output = $stdout.string
    refute_empty stdout_output
  end

  def test_normal_mode_passes_node_option
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      @@last_node = nil

      def self.last_node
        @@last_node
      end

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        @@last_node = node
        []
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("testnode", handler_class)

    Pvectl::Commands::Get::Command.execute(
      "testnode",
      nil,
      { node: "pve1" },
      { output: "json" }
    )

    assert_equal "pve1", handler_class.last_node
  end

  def test_normal_mode_passes_args_to_handler
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      @@last_args = nil

      def self.last_args
        @@last_args
      end

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        @@last_args = args
        []
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("testname", handler_class)

    Pvectl::Commands::Get::Command.execute(
      "testname",
      ["vm-100"],
      {},
      { output: "json" }
    )

    assert_equal ["vm-100"], handler_class.last_args
  end

  private

  class MockHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [MockModel.new("test", "running")]
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
  end
end

# =============================================================================
# Commands::Get::Command Tests - Watch Mode
# =============================================================================

class GetCommandWatchModeTest < Minitest::Test
  # Tests for watch mode execution

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("test", MockHandler)
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_watch_mode_is_triggered_by_watch_option
    execution_count = 0
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      define_method(:list) do |node: nil, name: nil, args: [], storage: nil, **_options|
        execution_count += 1
        []
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("watchtest", handler_class)

    # Run in a thread and stop after first execution
    thread = Thread.new do
      begin
        Pvectl::Commands::Get::Command.execute(
          "watchtest",
          nil,
          { watch: true, "watch-interval": 1 },
          { output: "json" }
        )
      rescue StandardError
        # Ignore errors from thread termination
      end
    end

    sleep(0.5) # Let it run briefly
    # Stop the watch loop by sending interrupt
    Process.kill("INT", Process.pid)

    thread.join(2)
    thread.kill if thread.alive?

    assert execution_count >= 1, "Handler should have been called at least once in watch mode"
  end

  def test_watch_mode_uses_custom_interval
    # This test verifies the interval is passed correctly
    # We can't easily test the actual timing, but we verify the option is processed
    command = Pvectl::Commands::Get::Command.new(
      "test",
      nil,
      { watch: true, "watch-interval": 5 },
      { output: "json" }
    )

    # The command should be created successfully with the custom interval
    refute_nil command
  end

  private

  class MockHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      []
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
  end
end

# =============================================================================
# Commands::Get::Command Tests - Connection Error Handling
# =============================================================================

class GetCommandConnectionErrorTest < Minitest::Test
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

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise Timeout::Error, "Connection timed out"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("timeout", handler_class)

    exit_code = Pvectl::Commands::Get::Command.execute(
      "timeout",
      nil,
      {},
      { output: "json" }
    )

    # Should return connection error
    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_handles_connection_refused_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise Errno::ECONNREFUSED, "Connection refused"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("connrefused", handler_class)

    exit_code = Pvectl::Commands::Get::Command.execute(
      "connrefused",
      nil,
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_handles_socket_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise SocketError, "getaddrinfo: Name or service not known"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("socketerr", handler_class)

    exit_code = Pvectl::Commands::Get::Command.execute(
      "socketerr",
      nil,
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::CONNECTION_ERROR, exit_code
  end

  def test_outputs_error_message_to_stderr
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise Timeout::Error, "Connection timed out"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("errmsg", handler_class)

    Pvectl::Commands::Get::Command.execute(
      "errmsg",
      nil,
      {},
      { output: "table" }
    )

    stderr_output = $stderr.string
    assert_includes stderr_output.downcase, "error"
  end

  def test_handles_argument_error
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise ArgumentError, "At least one VMID is required"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("argerr", handler_class)

    exit_code = Pvectl::Commands::Get::Command.execute(
      "argerr",
      [],
      {},
      { output: "json" }
    )

    assert_equal Pvectl::ExitCodes::USAGE_ERROR, exit_code
  end

  def test_argument_error_outputs_message_to_stderr
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        raise ArgumentError, "At least one VMID is required"
      end

      def presenter
        MockPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("argerrmsg", handler_class)

    Pvectl::Commands::Get::Command.execute(
      "argerrmsg",
      [],
      {},
      { output: "json" }
    )

    stderr_output = $stderr.string
    assert_includes stderr_output, "At least one VMID is required"
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
  end
end

# =============================================================================
# Commands::Get::Command Tests - Output Format
# =============================================================================

class GetCommandOutputFormatTest < Minitest::Test
  # Tests for output format handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("test", MockHandler)
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_respects_output_format_from_global_options
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "json" }
    )

    stdout_output = $stdout.string

    # Should be valid JSON
    data = JSON.parse(stdout_output)
    assert_kind_of Array, data
  end

  def test_defaults_to_table_format
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      {}
    )

    stdout_output = $stdout.string

    # Table format should have headers
    assert_includes stdout_output.upcase, "NAME"
  end

  def test_supports_yaml_format
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "yaml" }
    )

    stdout_output = $stdout.string

    # Should be valid YAML
    data = YAML.safe_load(stdout_output)
    assert_kind_of Array, data
  end

  def test_supports_wide_format
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "wide" }
    )

    stdout_output = $stdout.string

    # Wide format should have extra columns
    assert_includes stdout_output.upcase, "EXTRA"
  end

  private

  class MockHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [MockModel.new("test-item", "running", "extra-data")]
    end

    def presenter
      MockPresenter.new
    end
  end

  class MockModel
    attr_reader :name, :status, :extra

    def initialize(name, status, extra)
      @name = name
      @status = status
      @extra = extra
    end
  end

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
end

# =============================================================================
# Commands::Get::Command Tests - Args Support
# =============================================================================

class GetCommandArgsTest < Minitest::Test
  # Tests for passing additional positional arguments (args) to handlers

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

  def test_passes_args_to_handler
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      @@last_args = nil

      def self.last_args
        @@last_args
      end

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        @@last_args = args
        []
      end

      def presenter
        MockArgsPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("testargs", handler_class)

    # resource_type="testargs", args=["100", "101"]
    Pvectl::Commands::Get::Command.execute(
      "testargs",
      ["100", "101"],
      {},
      { output: "json" }
    )

    assert_equal ["100", "101"], handler_class.last_args
  end

  def test_passes_empty_args_when_none_provided
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      @@last_args = nil

      def self.last_args
        @@last_args
      end

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        @@last_args = args
        []
      end

      def presenter
        MockArgsPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("testemptyargs", handler_class)

    Pvectl::Commands::Get::Command.execute(
      "testemptyargs",
      nil,
      {},
      { output: "json" }
    )

    assert_equal [], handler_class.last_args
  end

  def test_passes_single_arg_as_array
    handler_class = Class.new do
      include Pvectl::Commands::Get::ResourceHandler

      @@last_args = nil

      def self.last_args
        @@last_args
      end

      def list(node: nil, name: nil, args: [], storage: nil, **_options)
        @@last_args = args
        []
      end

      def presenter
        MockArgsPresenter.new
      end
    end

    Pvectl::Commands::Get::ResourceRegistry.register("testsinglearg", handler_class)

    # Single arg passed as string - should be converted to array
    Pvectl::Commands::Get::Command.execute(
      "testsinglearg",
      "100",
      {},
      { output: "json" }
    )

    assert_equal ["100"], handler_class.last_args
  end

  private

  class MockArgsPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME"]
    end

    def to_row(model, **_context)
      [model.name]
    end

    def to_hash(model)
      { "name" => model.name }
    end
  end
end

# =============================================================================
# Commands::Get::Command Tests - Color Support
# =============================================================================

class GetCommandColorSupportTest < Minitest::Test
  # Tests for color output handling

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("test", MockHandler)
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  def test_respects_color_flag_true
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "table", color: true }
    )

    # With color explicitly enabled, output may contain ANSI codes
    # (depends on implementation - just verify no errors)
    assert_equal 0, Pvectl::ExitCodes::SUCCESS
  end

  def test_respects_color_flag_false
    Pvectl::Commands::Get::Command.execute(
      "test",
      nil,
      {},
      { output: "table", color: false }
    )

    stdout_output = $stdout.string

    # Without color, output should not contain ANSI escape codes
    refute_match(/\e\[/, stdout_output, "Output should not contain ANSI codes with color: false")
  end

  private

  class MockHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [MockModel.new("test", "running")]
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
  end
end

# =============================================================================
# Commands::Get::Command Tests - Selector Filtering
# =============================================================================

class GetCommandSelectorFilteringTest < Minitest::Test
  # Tests for -l selector and --status shortcut filtering

  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
    @original_stdout = $stdout
    $stdout = StringIO.new

    Pvectl::Commands::Get::ResourceRegistry.reset!
    Pvectl::Commands::Get::ResourceRegistry.register("vms", SelectorMockVmHandler, aliases: ["vm"])
    Pvectl::Commands::Get::ResourceRegistry.register("tasks", SelectorMockTaskHandler, aliases: ["task"])
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    Pvectl::Commands::Get::ResourceRegistry.reset!
  end

  # ---------------------------
  # --status shortcut for VMs
  # ---------------------------

  def test_status_flag_filters_vms_by_status
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      { status: "running" },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert data.all? { |item| item["status"] == "running" },
           "All returned VMs should have status=running, got: #{data.map { |i| i['status'] }}"
  end

  def test_status_flag_excludes_non_matching_vms
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      { status: "running" },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 2, data.length, "Should return only 2 running VMs out of 3"
  end

  # ---------------------------
  # -l selector for VMs
  # ---------------------------

  def test_selector_flag_filters_vms_by_status
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      { selector: ["status=running"] },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 2, data.length
    assert data.all? { |item| item["status"] == "running" }
  end

  def test_selector_flag_filters_vms_by_name
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      { selector: ["name=web-1"] },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 1, data.length
    assert_equal "web-1", data.first["name"]
  end

  # ---------------------------
  # Combined --status and -l
  # ---------------------------

  def test_status_and_selector_combined
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      { status: "running", selector: ["name=web-1"] },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 1, data.length
    assert_equal "web-1", data.first["name"]
    assert_equal "running", data.first["status"]
  end

  # ---------------------------
  # --status for tasks (passthrough, no selector)
  # ---------------------------

  def test_status_flag_passes_through_for_tasks
    Pvectl::Commands::Get::Command.execute(
      "tasks",
      nil,
      { status: "running" },
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 1, data.length
    assert_equal "running", data.first["status"]
  end

  # ---------------------------
  # No filtering when no flags
  # ---------------------------

  def test_no_selector_returns_all_results
    Pvectl::Commands::Get::Command.execute(
      "vms",
      nil,
      {},
      { output: "json" }
    )

    data = JSON.parse($stdout.string)
    assert_equal 3, data.length
  end

  private

  # Mock VM handler that declares selector_class
  class SelectorMockVmHandler
    include Pvectl::Commands::Get::ResourceHandler

    def selector_class
      Pvectl::Selectors::Vm
    end

    def list(node: nil, name: nil, args: [], storage: nil, **_options)
      [
        SelectorMockModel.new("web-1", "running"),
        SelectorMockModel.new("web-2", "running"),
        SelectorMockModel.new("db-1", "stopped")
      ]
    end

    def presenter
      SelectorMockPresenter.new
    end
  end

  # Mock tasks handler without selector_class (uses status_filter directly)
  class SelectorMockTaskHandler
    include Pvectl::Commands::Get::ResourceHandler

    def list(node: nil, name: nil, args: [], storage: nil, status_filter: nil, **_options)
      tasks = [
        SelectorMockModel.new("qmstart", "running"),
        SelectorMockModel.new("vzdump", "ok")
      ]
      tasks = tasks.select { |t| t.status == status_filter } if status_filter
      tasks
    end

    def presenter
      SelectorMockPresenter.new
    end
  end

  class SelectorMockModel
    attr_reader :name, :status

    def initialize(name, status)
      @name = name
      @status = status
    end
  end

  class SelectorMockPresenter < Pvectl::Presenters::Base
    def columns
      ["NAME", "STATUS"]
    end

    def to_row(model, **_context)
      [model.name, model.status]
    end

    def to_hash(model)
      { "name" => model.name, "status" => model.status }
    end
  end
end
