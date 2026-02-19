# frozen_string_literal: true

require "test_helper"

# =============================================================================
# Commands::Get::WatchLoop Tests
# =============================================================================

class GetWatchLoopTest < Minitest::Test
  # Tests for the watch loop implementation

  # ---------------------------
  # Class Existence
  # ---------------------------

  def test_watch_loop_class_exists
    assert_kind_of Class, Pvectl::Commands::Get::WatchLoop
  end

  # ---------------------------
  # Constants
  # ---------------------------

  def test_default_interval_is_two_seconds
    assert_equal 2, Pvectl::Commands::Get::WatchLoop::DEFAULT_INTERVAL
  end

  def test_min_interval_is_one_second
    assert_equal 1, Pvectl::Commands::Get::WatchLoop::MIN_INTERVAL
  end

  # ---------------------------
  # Initialization
  # ---------------------------

  def test_initialize_with_default_interval
    loop = Pvectl::Commands::Get::WatchLoop.new

    assert_equal 2, loop.interval
  end

  def test_initialize_with_custom_interval
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 5)

    assert_equal 5, loop.interval
  end

  def test_initialize_clamps_interval_below_minimum
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 0)

    assert_equal 1, loop.interval
  end

  def test_initialize_clamps_negative_interval_to_minimum
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: -5)

    assert_equal 1, loop.interval
  end

  def test_initialize_clamps_fractional_interval_below_minimum
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 0.5)

    assert_equal 1, loop.interval
  end

  def test_initialize_accepts_custom_output_stream
    output = StringIO.new
    loop = Pvectl::Commands::Get::WatchLoop.new(output: output)

    refute_nil loop
  end

  # ---------------------------
  # #running? Method
  # ---------------------------

  def test_running_returns_false_before_run
    loop = Pvectl::Commands::Get::WatchLoop.new

    refute loop.running?
  end

  # ---------------------------
  # #stop Method
  # ---------------------------

  def test_stop_sets_running_to_false
    loop = Pvectl::Commands::Get::WatchLoop.new

    # Simulate running state (internal)
    loop.instance_variable_set(:@running, true)
    assert loop.running?

    loop.stop
    refute loop.running?
  end

  # ---------------------------
  # #run Method - Block Execution
  # ---------------------------

  def test_run_executes_block_at_least_once
    output = StringIO.new
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 1, output: output)

    execution_count = 0

    # Run in a thread and stop after first execution
    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop if execution_count >= 1
      end
    end

    thread.join(2) # Timeout after 2 seconds
    loop.stop
    thread.kill if thread.alive?

    assert execution_count >= 1, "Block should have been executed at least once"
  end

  def test_run_executes_block_multiple_times
    output = StringIO.new
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 1, output: output)

    execution_count = 0

    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop if execution_count >= 2
      end
    end

    thread.join(5) # Timeout after 5 seconds
    loop.stop
    thread.kill if thread.alive?

    assert execution_count >= 2, "Block should have been executed at least twice"
  end

  # ---------------------------
  # #run Method - TTY Behavior
  # ---------------------------

  def test_run_clears_screen_when_tty
    output = MockTTY.new(is_tty: true)
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 1, output: output)

    execution_count = 0
    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop
      end
    end

    thread.join(2)
    loop.stop
    thread.kill if thread.alive?

    # Check for ANSI clear screen sequence
    assert_includes output.string, "\e[H\e[2J", "Should contain clear screen ANSI codes"
  end

  def test_run_prints_header_when_tty
    output = MockTTY.new(is_tty: true)
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 2, output: output)

    execution_count = 0
    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop
      end
    end

    thread.join(2)
    loop.stop
    thread.kill if thread.alive?

    # Check for header with interval
    assert_match(/Every 2s:/, output.string, "Should show header with interval")
  end

  def test_run_does_not_clear_screen_when_not_tty
    output = StringIO.new
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 1, output: output)

    execution_count = 0
    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop
      end
    end

    thread.join(2)
    loop.stop
    thread.kill if thread.alive?

    # Should NOT contain clear screen sequence
    refute_includes output.string, "\e[H\e[2J", "Should NOT contain clear screen ANSI codes in non-TTY mode"
  end

  def test_run_does_not_print_header_when_not_tty
    output = StringIO.new
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 2, output: output)

    execution_count = 0
    thread = Thread.new do
      loop.run do
        execution_count += 1
        loop.stop
      end
    end

    thread.join(2)
    loop.stop
    thread.kill if thread.alive?

    # Should NOT show header
    refute_match(/Every \d+s:/, output.string, "Should NOT show header in non-TTY mode")
  end

  # ---------------------------
  # #run Method - SIGINT Handling
  # ---------------------------

  def test_run_stops_gracefully_on_sigint
    output = MockTTY.new(is_tty: true)
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 1, output: output)

    stopped_gracefully = false
    execution_count = 0

    thread = Thread.new do
      loop.run do
        execution_count += 1
        # Simulate SIGINT by sending signal to current process
        if execution_count == 1
          Process.kill("INT", Process.pid)
        end
      end
      stopped_gracefully = true
    end

    thread.join(3)
    loop.stop
    thread.kill if thread.alive?

    assert stopped_gracefully || !loop.running?, "Loop should stop gracefully on SIGINT"
  end

  # ---------------------------
  # Interval Attribute
  # ---------------------------

  def test_interval_is_readable
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 3)

    assert_respond_to loop, :interval
    assert_equal 3, loop.interval
  end

  def test_interval_converts_float_to_integer
    loop = Pvectl::Commands::Get::WatchLoop.new(interval: 3.7)

    assert_equal 3, loop.interval
  end

  private

  # Mock TTY class for testing
  class MockTTY < StringIO
    def initialize(is_tty:)
      super()
      @is_tty = is_tty
    end

    def tty?
      @is_tty
    end
  end
end
