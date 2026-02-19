# frozen_string_literal: true

require "rest-client"
require "timeout"

module Pvectl
  class Connection
    # Handles retry logic with exponential backoff for API requests.
    #
    # RetryHandler wraps API calls to automatically retry on transient errors
    # like network timeouts, server errors (5xx), and rate limiting (429).
    # By default, only read operations (GET) are retried; write operations
    # require explicit opt-in via retry_writes due to idempotency concerns.
    #
    # @example Basic usage with read operation
    #   handler = RetryHandler.new(max_retries: 3, base_delay: 1, max_delay: 30)
    #   result = handler.with_retry(method: :get) { api.nodes.get }
    #
    # @example Write operation with retries disabled (default)
    #   handler.with_retry(method: :post) { api.nodes[node].qemu.post(data) }
    #   # Will NOT retry on failure
    #
    # @example Write operation with retries enabled
    #   handler = RetryHandler.new(max_retries: 3, base_delay: 1, max_delay: 30, retry_writes: true)
    #   handler.with_retry(method: :post) { api.nodes[node].qemu.post(data) }
    #   # Will retry on transient failures
    #
    class RetryHandler
      # Exceptions that indicate transient failures safe to retry.
      #
      # Includes:
      # - Connection timeouts (OpenTimeout, ReadTimeout)
      # - Server errors (5xx)
      # - Rate limiting (429)
      # - Network errors (ECONNREFUSED, ECONNRESET, SocketError)
      # - Global timeout (Timeout::Error from Ruby's Timeout module)
      RETRYABLE_EXCEPTIONS = [
        RestClient::Exceptions::OpenTimeout,
        RestClient::Exceptions::ReadTimeout,
        RestClient::InternalServerError,     # 500
        RestClient::BadGateway,              # 502
        RestClient::ServiceUnavailable,      # 503
        RestClient::GatewayTimeout,          # 504
        RestClient::TooManyRequests,         # 429
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        SocketError,
        Timeout::Error
      ].freeze

      # HTTP methods considered safe to retry (read-only, idempotent).
      READ_METHODS = %i[get head options].freeze

      # @return [Integer] maximum number of retry attempts
      attr_reader :max_retries

      # @return [Numeric] base delay in seconds for exponential backoff
      attr_reader :base_delay

      # @return [Numeric] maximum delay cap in seconds
      attr_reader :max_delay

      # @return [Boolean] whether to retry write operations
      attr_reader :retry_writes

      # @return [Logger, nil] optional logger for retry messages
      attr_reader :logger

      # Creates a new RetryHandler.
      #
      # @param max_retries [Integer] maximum number of retry attempts (0 = no retries)
      # @param base_delay [Numeric] base delay in seconds for exponential backoff
      # @param max_delay [Numeric] maximum delay cap in seconds
      # @param retry_writes [Boolean] whether to retry write operations (default: false)
      # @param logger [Logger, nil] optional logger for retry messages
      def initialize(max_retries:, base_delay:, max_delay:, retry_writes: false, logger: nil)
        @max_retries = max_retries
        @base_delay = base_delay
        @max_delay = max_delay
        @retry_writes = retry_writes
        @logger = logger
      end

      # Executes a block with retry logic.
      #
      # Retries the block on transient errors using exponential backoff.
      # By default, only read operations (GET, HEAD, OPTIONS) are retried.
      # Write operations require retry_writes: true in the constructor.
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, :delete, :head, :options)
      # @yield the API call to execute
      # @return [Object] result of the block
      # @raise [Exception] the last error after all retries exhausted
      #
      # @example
      #   handler.with_retry(method: :get) { api.nodes.get }
      def with_retry(method: :get)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue *RETRYABLE_EXCEPTIONS => e
          raise unless should_retry?(method, attempts)

          delay = calculate_delay(attempts)
          log_retry(attempts, delay, e)
          sleep(delay)
          retry
        end
      end

      private

      # Determines if the operation should be retried.
      #
      # @param method [Symbol] HTTP method
      # @param attempts [Integer] current attempt count (1-based)
      # @return [Boolean] true if retry should be attempted
      def should_retry?(method, attempts)
        return false if attempts > max_retries
        return true if READ_METHODS.include?(method)

        retry_writes
      end

      # Calculates delay using exponential backoff.
      #
      # Formula: delay = min(base_delay * 2^(attempt-1), max_delay)
      #
      # Example with base_delay=1, max_delay=30:
      # - Attempt 1: 1s
      # - Attempt 2: 2s
      # - Attempt 3: 4s
      # - Attempt 4: 8s
      # - Attempt 5+: capped at 30s
      #
      # @param attempt [Integer] current attempt number (1-based)
      # @return [Numeric] delay in seconds
      def calculate_delay(attempt)
        delay = base_delay * (2**(attempt - 1))
        [delay, max_delay].min
      end

      # Logs a retry attempt.
      #
      # Security: Only logs error class name, NOT error.message which may
      # contain sensitive data (URLs with tokens, request bodies, etc.)
      #
      # @param attempt [Integer] current attempt number
      # @param delay [Numeric] delay before next attempt
      # @param error [Exception] the error that triggered the retry
      def log_retry(attempt, delay, error)
        return unless logger

        logger.warn(
          "Retry #{attempt}/#{max_retries} after #{delay}s: #{error.class.name}"
        )
      end
    end
  end
end
