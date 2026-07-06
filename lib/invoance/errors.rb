# frozen_string_literal: true

module Invoance
  # Base error for everything the SDK raises — API responses, network
  # failures, and client-side validation. A single
  # `rescue Invoance::Error` catches anything the SDK throws.
  #
  #   begin
  #     client.events.ingest(event_type: "user.login", payload: { user_id: "u_42" })
  #   rescue Invoance::QuotaExceededError
  #     puts "Upgrade your plan"
  #   rescue Invoance::TimeoutError
  #     puts "Request timed out — retrying"
  #   rescue Invoance::Error => e
  #     puts "Invoance error: #{e.message}"
  #   end
  class Error < StandardError
    attr_reader :status_code, :error_code, :body, :retry_after_seconds, :request_context

    # @param message [String]
    # @param status_code [Integer, nil]
    # @param error_code [String, nil]
    # @param body [Hash, nil] parsed JSON body (string keys)
    # @param retry_after_seconds [Numeric, nil]
    # @param request_context [Hash, nil] { method:, path: }
    def initialize(message, status_code: nil, error_code: nil, body: nil,
                   retry_after_seconds: nil, request_context: nil)
      super(message)
      @status_code = status_code
      @error_code = error_code
      @body = body
      @retry_after_seconds = retry_after_seconds
      @request_context = request_context
    end
  end

  class AuthenticationError < Error; end
  class ForbiddenError < Error; end
  class NotFoundError < Error; end

  # 400 from the server, and also raised client-side for bad input.
  class ValidationError < Error; end

  class ConflictError < Error; end
  class QuotaExceededError < Error; end
  class ServerError < Error; end

  # Raised when the request fails before a response is received —
  # DNS failure, connection refused, TLS handshake error, etc.
  class NetworkError < Error; end

  # Raised when the request exceeds the configured timeout.
  class TimeoutError < Error; end

  # Status-code → error-class map. Anything >= 500 not listed maps to
  # ServerError; any other unmapped status maps to the base Error.
  STATUS_ERROR_MAP = {
    400 => ValidationError,
    401 => AuthenticationError,
    403 => ForbiddenError,
    404 => NotFoundError,
    409 => ConflictError,
    429 => QuotaExceededError
  }.freeze

  # Raise the appropriate error for a non-2xx response. No-op on 2xx.
  #
  # @param status_code [Integer]
  # @param body [Hash, nil] parsed JSON body (string keys), or nil
  # @param request_context [Hash, nil] { method:, path: }
  # @param retry_after_seconds [Numeric, nil]
  def self.throw_for_status(status_code, body, request_context: nil, retry_after_seconds: nil)
    return if status_code >= 200 && status_code < 300

    b = body || {}
    error_code = b["error"] || "unknown"
    server_message = b["message"]

    message =
      if server_message
        server_message
      elsif status_code == 429 && !retry_after_seconds.nil?
        "HTTP 429#{describe_request(request_context)} — rate limited, retry after #{retry_after_seconds}s"
      else
        "HTTP #{status_code}#{describe_request(request_context)} (no response body)"
      end

    klass = STATUS_ERROR_MAP[status_code] || (status_code >= 500 ? ServerError : Error)

    raise klass.new(
      message,
      status_code: status_code,
      error_code: error_code,
      body: b,
      request_context: request_context,
      retry_after_seconds: retry_after_seconds
    )
  end

  # @api private
  def self.describe_request(ctx)
    ctx ? " on #{ctx[:method]} #{ctx[:path]}" : ""
  end
end
