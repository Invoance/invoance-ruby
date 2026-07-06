# frozen_string_literal: true

module Invoance
  # Resolved, immutable SDK configuration.
  #
  # All fields are optional at the client boundary — when omitted the SDK
  # reads from environment variables:
  #
  #   * INVOANCE_API_KEY  — API key (required)
  #   * INVOANCE_BASE_URL — API host (defaults to https://api.invoance.com)
  class Config
    DEFAULT_BASE_URL = "https://api.invoance.com"
    DEFAULT_TIMEOUT = 30
    ENV_API_KEY = "INVOANCE_API_KEY"
    ENV_BASE_URL = "INVOANCE_BASE_URL"

    attr_reader :api_key, :base_url, :api_version, :timeout, :idempotency_key, :extra_headers

    # @param api_key [String, nil]
    # @param base_url [String, nil]
    # @param api_version [String]
    # @param timeout [Numeric] request timeout in seconds
    # @param idempotency_key [String, nil] default idempotency key for mutating requests
    # @param extra_headers [Hash] merged into every request
    def initialize(api_key: nil, base_url: nil, api_version: "v1", timeout: DEFAULT_TIMEOUT,
                   idempotency_key: nil, extra_headers: {})
      resolved_key = api_key || ENV[ENV_API_KEY] || ""
      if resolved_key.empty?
        raise ArgumentError,
              "api_key is required. Pass it explicitly or set the #{ENV_API_KEY} environment variable."
      end

      @api_key = resolved_key
      @base_url = (base_url || ENV[ENV_BASE_URL] || DEFAULT_BASE_URL).sub(%r{/+\z}, "")
      @api_version = (api_version || "v1").gsub(%r{\A/+|/+\z}, "")
      @timeout = timeout || DEFAULT_TIMEOUT
      @idempotency_key = idempotency_key
      @extra_headers = extra_headers || {}
    end
  end
end
