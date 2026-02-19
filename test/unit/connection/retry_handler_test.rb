# frozen_string_literal: true

require "test_helper"
require "logger"
require "stringio"

# =============================================================================
# Connection::RetryHandler Tests - Success Cases
# =============================================================================

class ConnectionRetryHandlerSuccessTest < Minitest::Test
  # Test success scenarios - block executes without retry

  def setup
    @handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 1,
      max_delay: 30
    )
  end

  def test_retry_handler_class_exists
    assert_kind_of Class, Pvectl::Connection::RetryHandler
  end

  def test_executes_block_on_success_without_retrying
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      "success"
    end

    assert_equal 1, call_count
    assert_equal "success", result
  end

  def test_returns_block_result_on_success
    result = @handler.with_retry(method: :get) { { data: "value" } }

    assert_equal({ data: "value" }, result)
  end

  def test_has_max_retries_attribute
    assert_equal 3, @handler.max_retries
  end

  def test_has_base_delay_attribute
    assert_equal 1, @handler.base_delay
  end

  def test_has_max_delay_attribute
    assert_equal 30, @handler.max_delay
  end

  def test_has_retry_writes_attribute_default_false
    assert_equal false, @handler.retry_writes
  end

  def test_has_logger_attribute_default_nil
    assert_nil @handler.logger
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Retry for GET Operations
# =============================================================================

class ConnectionRetryHandlerGetRetryTest < Minitest::Test
  # Test that GET requests retry on transient errors

  def setup
    @handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 0.001, # Very short for tests
      max_delay: 0.01
    )
  end

  def test_retries_get_on_open_timeout
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::Exceptions::OpenTimeout if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_read_timeout
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::Exceptions::ReadTimeout if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_timeout_error
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise Timeout::Error if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_internal_server_error
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::InternalServerError if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_bad_gateway
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::BadGateway if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_service_unavailable
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::ServiceUnavailable if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_gateway_timeout
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::GatewayTimeout if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_too_many_requests
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::TooManyRequests if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_connection_refused
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise Errno::ECONNREFUSED if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_connection_reset
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise Errno::ECONNRESET if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_get_on_socket_error
    call_count = 0

    result = @handler.with_retry(method: :get) do
      call_count += 1
      raise SocketError if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end
end

# =============================================================================
# Connection::RetryHandler Tests - No Retry for Write Operations by Default
# =============================================================================

class ConnectionRetryHandlerWriteNoRetryTest < Minitest::Test
  # Test that write operations do NOT retry by default

  def setup
    @handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 0.001,
      max_delay: 0.01,
      retry_writes: false
    )
  end

  def test_does_not_retry_post_by_default
    call_count = 0

    assert_raises(RestClient::Exceptions::OpenTimeout) do
      @handler.with_retry(method: :post) do
        call_count += 1
        raise RestClient::Exceptions::OpenTimeout
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_put_by_default
    call_count = 0

    assert_raises(Errno::ECONNREFUSED) do
      @handler.with_retry(method: :put) do
        call_count += 1
        raise Errno::ECONNREFUSED
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_delete_by_default
    call_count = 0

    assert_raises(RestClient::ServiceUnavailable) do
      @handler.with_retry(method: :delete) do
        call_count += 1
        raise RestClient::ServiceUnavailable
      end
    end

    assert_equal 1, call_count
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Retry Write Operations When Enabled
# =============================================================================

class ConnectionRetryHandlerWriteRetryEnabledTest < Minitest::Test
  # Test that write operations retry when retry_writes is true

  def setup
    @handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 0.001,
      max_delay: 0.01,
      retry_writes: true
    )
  end

  def test_retries_post_when_retry_writes_enabled
    call_count = 0

    result = @handler.with_retry(method: :post) do
      call_count += 1
      raise RestClient::Exceptions::OpenTimeout if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_put_when_retry_writes_enabled
    call_count = 0

    result = @handler.with_retry(method: :put) do
      call_count += 1
      raise Errno::ECONNREFUSED if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end

  def test_retries_delete_when_retry_writes_enabled
    call_count = 0

    result = @handler.with_retry(method: :delete) do
      call_count += 1
      raise RestClient::ServiceUnavailable if call_count < 3

      "success"
    end

    assert_equal 3, call_count
    assert_equal "success", result
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Non-Retryable Errors (Never Retry)
# =============================================================================

class ConnectionRetryHandlerNonRetryableTest < Minitest::Test
  # Test that client errors (4xx) are never retried, even for GET

  def setup
    @handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 0.001,
      max_delay: 0.01,
      retry_writes: true # Even with writes enabled, 4xx should not retry
    )
  end

  def test_does_not_retry_bad_request
    call_count = 0

    assert_raises(RestClient::BadRequest) do
      @handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::BadRequest
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_unauthorized
    call_count = 0

    assert_raises(RestClient::Unauthorized) do
      @handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::Unauthorized
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_forbidden
    call_count = 0

    assert_raises(RestClient::Forbidden) do
      @handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::Forbidden
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_not_found
    call_count = 0

    assert_raises(RestClient::NotFound) do
      @handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::NotFound
      end
    end

    assert_equal 1, call_count
  end

  def test_does_not_retry_generic_exception
    call_count = 0

    assert_raises(RuntimeError) do
      @handler.with_retry(method: :get) do
        call_count += 1
        raise "Generic error"
      end
    end

    assert_equal 1, call_count
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Retry Exhaustion and Backoff
# =============================================================================

class ConnectionRetryHandlerExhaustionTest < Minitest::Test
  # Test retry exhaustion and exponential backoff

  def test_raises_after_max_retries_exhausted
    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 3,
      base_delay: 0.001,
      max_delay: 0.01
    )
    call_count = 0

    assert_raises(RestClient::Exceptions::OpenTimeout) do
      handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::Exceptions::OpenTimeout
      end
    end

    # 1 initial attempt + 3 retries = 4 total calls
    assert_equal 4, call_count
  end

  def test_zero_retries_means_no_retry
    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 0,
      base_delay: 0.001,
      max_delay: 0.01
    )
    call_count = 0

    assert_raises(RestClient::Exceptions::OpenTimeout) do
      handler.with_retry(method: :get) do
        call_count += 1
        raise RestClient::Exceptions::OpenTimeout
      end
    end

    assert_equal 1, call_count
  end

  def test_exponential_backoff_calculation
    # Create handler and capture delays
    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 5,
      base_delay: 1,
      max_delay: 30
    )

    # Test internal delay calculation via private method
    # Attempt 1: 1 * 2^0 = 1
    # Attempt 2: 1 * 2^1 = 2
    # Attempt 3: 1 * 2^2 = 4
    # Attempt 4: 1 * 2^3 = 8
    # Attempt 5: 1 * 2^4 = 16
    assert_equal 1, handler.send(:calculate_delay, 1)
    assert_equal 2, handler.send(:calculate_delay, 2)
    assert_equal 4, handler.send(:calculate_delay, 3)
    assert_equal 8, handler.send(:calculate_delay, 4)
    assert_equal 16, handler.send(:calculate_delay, 5)
  end

  def test_delay_caps_at_max_delay
    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 10,
      base_delay: 1,
      max_delay: 10
    )

    # Attempt 5: 1 * 2^4 = 16, but capped at 10
    assert_equal 10, handler.send(:calculate_delay, 5)
    # Attempt 10: 1 * 2^9 = 512, but capped at 10
    assert_equal 10, handler.send(:calculate_delay, 10)
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Logging
# =============================================================================

class ConnectionRetryHandlerLoggingTest < Minitest::Test
  # Test logging behavior

  def test_logs_retry_attempts_when_logger_provided
    log_output = StringIO.new
    logger = Logger.new(log_output)
    logger.level = Logger::WARN

    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 2,
      base_delay: 0.001,
      max_delay: 0.01,
      logger: logger
    )

    call_count = 0

    handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::Exceptions::OpenTimeout if call_count < 3

      "success"
    end

    log_content = log_output.string

    # Should have logged 2 retry attempts
    assert_includes log_content, "Retry 1/2"
    assert_includes log_content, "Retry 2/2"
    assert_includes log_content, "OpenTimeout"
  end

  def test_does_not_log_when_logger_is_nil
    handler = Pvectl::Connection::RetryHandler.new(
      max_retries: 2,
      base_delay: 0.001,
      max_delay: 0.01,
      logger: nil
    )

    call_count = 0

    # Should not raise any errors about logging
    handler.with_retry(method: :get) do
      call_count += 1
      raise RestClient::Exceptions::OpenTimeout if call_count < 3

      "success"
    end

    assert_equal 3, call_count
  end
end

# =============================================================================
# Connection::RetryHandler Tests - Constants
# =============================================================================

class ConnectionRetryHandlerConstantsTest < Minitest::Test
  # Test that constants are defined correctly

  def test_retryable_exceptions_constant_exists
    assert_kind_of Array, Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS
  end

  def test_retryable_exceptions_includes_open_timeout
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::Exceptions::OpenTimeout
  end

  def test_retryable_exceptions_includes_read_timeout
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::Exceptions::ReadTimeout
  end

  def test_retryable_exceptions_includes_timeout_error
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    Timeout::Error
  end

  def test_retryable_exceptions_includes_server_errors
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::InternalServerError
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::BadGateway
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::ServiceUnavailable
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::GatewayTimeout
  end

  def test_retryable_exceptions_includes_rate_limiting
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    RestClient::TooManyRequests
  end

  def test_retryable_exceptions_includes_network_errors
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    Errno::ECONNREFUSED
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    Errno::ECONNRESET
    assert_includes Pvectl::Connection::RetryHandler::RETRYABLE_EXCEPTIONS,
                    SocketError
  end

  def test_read_methods_constant_exists
    assert_kind_of Array, Pvectl::Connection::RetryHandler::READ_METHODS
  end

  def test_read_methods_includes_get_head_options
    assert_includes Pvectl::Connection::RetryHandler::READ_METHODS, :get
    assert_includes Pvectl::Connection::RetryHandler::READ_METHODS, :head
    assert_includes Pvectl::Connection::RetryHandler::READ_METHODS, :options
  end

  def test_read_methods_does_not_include_write_methods
    refute_includes Pvectl::Connection::RetryHandler::READ_METHODS, :post
    refute_includes Pvectl::Connection::RetryHandler::READ_METHODS, :put
    refute_includes Pvectl::Connection::RetryHandler::READ_METHODS, :delete
  end
end
