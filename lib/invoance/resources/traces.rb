# frozen_string_literal: true

module Invoance
  module Resources
    # Traces resource — client.traces.*
    class Traces
      # @param http [Invoance::Http]
      def initialize(http)
        @http = http
      end

      # POST /traces — Create a new trace.
      # @return [Hash] CreateTraceResponse
      def create(label:, metadata: nil)
        body = { "label" => label }
        body["metadata"] = metadata if metadata
        @http.post("/traces", body)
      end

      # GET /traces — Paginated trace listing. status in open|sealed.
      # @return [Hash] ListTracesResponse
      def list(page: nil, limit: nil, status: nil)
        @http.get("/traces", { "page" => page, "limit" => limit, "status" => status })
      end

      # GET /traces/:trace_id — Trace detail with paginated events.
      # @return [Hash] TraceDetail
      def get(trace_id, event_page: nil, event_limit: nil)
        @http.get("/traces/#{trace_id}", {
                    "event_page" => event_page,
                    "event_limit" => event_limit
                  })
      end

      # DELETE /traces/:trace_id — Delete an empty open trace.
      # @return [Hash] DeleteTraceResponse
      def delete(trace_id)
        @http.delete("/traces/#{trace_id}")
      end

      # POST /traces/:trace_id/seal — Seal a trace (async, 202).
      # @return [Hash] SealTraceResponse
      def seal(trace_id)
        @http.post("/traces/#{trace_id}/seal", {})
      end

      # GET /traces/:trace_id/proof — Export proof bundle as JSON.
      # @return [Hash] TraceProofBundle
      def proof(trace_id)
        @http.get("/traces/#{trace_id}/proof")
      end

      # GET /traces/:trace_id/proof/pdf — Download proof bundle as PDF.
      # @return [String] raw binary PDF bytes
      def proof_pdf(trace_id)
        @http.get_bytes("/traces/#{trace_id}/proof/pdf")
      end
    end
  end
end
