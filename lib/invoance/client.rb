# frozen_string_literal: true

require_relative "config"
require_relative "http"
require_relative "errors"
require_relative "resources/events"
require_relative "resources/documents"
require_relative "resources/attestations"
require_relative "resources/traces"
require_relative "resources/audit"

module Invoance
  # Top-level SDK client.
  #
  #   # Reads INVOANCE_API_KEY / INVOANCE_BASE_URL from env automatically
  #   client = Invoance::Client.new
  #
  #   # Or pass explicitly to override
  #   client = Invoance::Client.new(api_key: "inv_live_abc123")
  #
  #   event = client.events.ingest(event_type: "user.login", payload: { user_id: "u_42" })
  class Client
    attr_reader :events, :documents, :attestations, :traces, :audit

    # @param api_key [String, nil]
    # @param base_url [String, nil]
    # @param api_version [String]
    # @param timeout [Numeric] seconds
    # @param idempotency_key [String, nil]
    # @param extra_headers [Hash]
    def initialize(api_key: nil, base_url: nil, api_version: "v1", timeout: 30,
                   idempotency_key: nil, extra_headers: {})
      @config = Config.new(
        api_key: api_key,
        base_url: base_url,
        api_version: api_version,
        timeout: timeout,
        idempotency_key: idempotency_key,
        extra_headers: extra_headers
      )
      @http = Http.new(@config)

      @events = Resources::Events.new(@http)
      @documents = Resources::Documents.new(@http)
      @attestations = Resources::Attestations.new(@http)
      @traces = Resources::Traces.new(@http)
      @audit = Resources::Audit.new(@http)
    end

    # The resolved base URL in use.
    # @return [String]
    def base_url
      @config.base_url
    end

    # Probe a cheap authenticated endpoint (GET /v1/events?limit=1) to
    # confirm the API key works. NEVER raises.
    #
    # @return [Hash] { "valid" =>, "reason" =>, "base_url" => }
    def validate
      base = @config.base_url
      begin
        @events.list(limit: 1)
        { "valid" => true, "reason" => nil, "base_url" => base }
      rescue AuthenticationError
        { "valid" => false,
          "reason" => "Authentication failed — check INVOANCE_API_KEY",
          "base_url" => base }
      rescue ForbiddenError
        { "valid" => true,
          "reason" => "API key authenticated but lacks permission to list events",
          "base_url" => base }
      rescue QuotaExceededError
        { "valid" => true,
          "reason" => "API key authenticated but currently rate limited",
          "base_url" => base }
      rescue NetworkError, TimeoutError => e
        { "valid" => false, "reason" => "Server unreachable: #{e.message}", "base_url" => base }
      rescue Error => e
        { "valid" => false, "reason" => e.message, "base_url" => base }
      end
    end
  end
end
