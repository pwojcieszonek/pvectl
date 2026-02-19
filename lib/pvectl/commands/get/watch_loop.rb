# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      # Handles continuous watch mode for the get command.
      #
      # Repeatedly executes a block at specified intervals, clearing the
      # screen between iterations when running in a TTY. Handles SIGINT
      # for graceful termination.
      #
      # @example Basic usage
      #   loop = WatchLoop.new(interval: 5)
      #   loop.run { puts Time.now }
      #
      # @example With custom interval (clamped to minimum)
      #   loop = WatchLoop.new(interval: 0.5)  # Will be clamped to 1 second
      #
      class WatchLoop
        # Default refresh interval in seconds.
        DEFAULT_INTERVAL = 2

        # Minimum allowed refresh interval in seconds.
        MIN_INTERVAL = 1

        # @return [Integer] the effective refresh interval
        attr_reader :interval

        # Creates a new WatchLoop.
        #
        # @param interval [Integer, Float] refresh interval in seconds
        #   Values below MIN_INTERVAL are automatically clamped.
        # @param output [IO] output stream for TTY detection (default: $stdout)
        def initialize(interval: DEFAULT_INTERVAL, output: $stdout)
          @interval = [interval.to_i, MIN_INTERVAL].max
          @output = output
          @running = false
        end

        # Runs the watch loop, executing the block repeatedly.
        #
        # @yield Block to execute on each iteration
        # @return [void]
        #
        # @example
        #   loop.run do
        #     models = handler.list
        #     puts format(models)
        #   end
        def run
          @running = true
          setup_signal_handler

          while @running
            clear_screen if tty?
            print_header if tty?
            yield
            sleep_interruptible(@interval)
          end
        end

        # Stops the watch loop.
        #
        # @return [void]
        def stop
          @running = false
        end

        # Checks if the loop is currently running.
        #
        # @return [Boolean] true if running
        def running?
          @running
        end

        private

        # Clears the terminal screen using ANSI escape codes.
        #
        # @return [void]
        def clear_screen
          @output.print "\e[H\e[2J"
        end

        # Prints the watch mode header with timestamp.
        #
        # @return [void]
        def print_header
          timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
          @output.puts "Every #{@interval}s: #{timestamp}"
          @output.puts
        end

        # Checks if output is a TTY.
        #
        # @return [Boolean] true if output is a TTY
        def tty?
          @output.tty?
        end

        # Sets up SIGINT handler for graceful termination.
        #
        # @return [void]
        def setup_signal_handler
          @previous_handler = trap("INT") do
            stop
            # Don't print newline in non-TTY mode to avoid extra output
            @output.puts if tty?
          end
        end

        # Sleeps for the specified duration, allowing interruption.
        #
        # Uses small sleep intervals to allow quick response to stop signal.
        #
        # @param duration [Integer] total sleep duration in seconds
        # @return [void]
        def sleep_interruptible(duration)
          remaining = duration
          while remaining > 0 && @running
            chunk = [remaining, 0.1].min
            sleep(chunk)
            remaining -= chunk
          end
        end
      end
    end
  end
end
