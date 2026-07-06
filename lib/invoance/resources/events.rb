# frozen_string_literal: true

require_relative "../errors"
require_relative "../validate"

module Invoance
  module Resources
    # Events resource — client.events.*
    class Events
      # @param http [Invoance::Http]
      def initialize(http)
        @http = http
      end

      # POST /events — Ingest a compliance event.
      #
      # @param event_type [String]
      # @param payload [Hash]
      # @param event_time [String, nil]
      # @param trace_id [String, nil]
      # @param idempotency_key [String, nil]
      # @return [Hash] IngestEventResponse
      def ingest(event_type:, payload:, event_time: nil, trace_id: nil, idempotency_key: nil)
        body = { "event_type" => event_type, "payload" => payload }
        body["event_time"] = event_time if event_time
        body["trace_id"] = trace_id if trace_id
        @http.post("/events", body, idempotency_key)
      end

      # GET /events — Paginated event listing.
      #
      # @return [Hash] ListEventsResponse
      def list(page: nil, limit: nil, date_from: nil, date_to: nil, event_type: nil)
        @http.get("/events", {
                    "page" => page,
                    "limit" => limit,
                    "date_from" => date_from,
                    "date_to" => date_to,
                    "event_type" => event_type
                  })
      end

      # GET /events/:event_id — Retrieve a single event.
      # @return [Hash] ComplianceEvent
      def get(event_id)
        @http.get("/events/#{event_id}")
      end

      # POST /events/:event_id/verify — Hash verification.
      #
      # Provide EITHER payload_hash (hex SHA-256) OR payload (raw JSON).
      # Passing neither raises {Invoance::ValidationError}.
      #
      # @return [Hash] VerifyEventResponse
      def verify(event_id, payload_hash: nil, payload: nil)
        if payload_hash.nil? && payload.nil?
          raise ValidationError, "events.verify requires either `payload_hash` or `payload`"
        end

        body = {}
        unless payload_hash.nil?
          Validate.assert_sha256_hex("payload_hash", payload_hash)
          body["payload_hash"] = payload_hash
        end
        body["payload"] = payload unless payload.nil?

        @http.post("/events/#{event_id}/verify", body)
      end
    end
  end
end
