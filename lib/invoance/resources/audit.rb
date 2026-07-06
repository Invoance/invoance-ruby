# frozen_string_literal: true

require "json"
require "digest"
require "time"

module Invoance
  module Resources
    # Deep-sort all Hash keys (alphabetically) then compact-serialize.
    # Matches Node's stableStringify: no null-stripping, no schema forcing.
    # @api private
    def self.stable_stringify(value)
      JSON.generate(sort_deep_for_stable(value))
    end

    # @api private
    def self.sort_deep_for_stable(v)
      case v
      when Array
        v.map { |x| sort_deep_for_stable(x) }
      when Hash
        v.keys.map(&:to_s).sort.each_with_object({}) do |k, out|
          orig = v.key?(k) ? k : k.to_sym
          out[k] = sort_deep_for_stable(v[orig])
        end
      else
        v
      end
    end

    # Derive a stable Idempotency-Key from an event body (safe-retry helper).
    #
    # @param body [Hash]
    # @return [String]
    def self.content_idempotency_key(body)
      "idem_" + Digest::SHA256.hexdigest(stable_stringify(body))
    end

    # Audit Logs resource — client.audit.*
    #
    # Five sub-resources: events, orgs, streams, portal_sessions, exports.
    class Audit
      # audit.events.*
      class Events
        def initialize(http)
          @http = http
        end

        # POST /audit/events — append one signed event.
        # The ledger REQUIRES an Idempotency-Key; derive a content-stable one
        # when none is provided.
        # @return [Hash]
        def ingest(organization_id:, action:, actor:, occurred_at: nil, targets: nil,
                   context: nil, metadata: nil, idempotency_key: nil)
          body = {
            "organization_id" => organization_id,
            "action" => action,
            "occurred_at" => occurred_at || Time.now.utc.iso8601,
            "actor" => actor,
            "targets" => targets.nil? ? [] : targets
          }
          body["context"] = context if context
          body["metadata"] = metadata if metadata
          idem = idempotency_key || Resources.content_idempotency_key(body)
          @http.post("/audit/events", body, idem)
        end

        # GET /audit/events — keyset-paginated listing.
        # @return [Hash] ListAuditEventsResponse
        def list(organization_id: nil, actions: nil, actor_id: nil, target_id: nil,
                 range_start: nil, range_end: nil, limit: nil, cursor: nil)
          @http.get("/audit/events", {
                      "organization_id" => organization_id,
                      "actions" => actions,
                      "actor_id" => actor_id,
                      "target_id" => target_id,
                      "range_start" => range_start,
                      "range_end" => range_end,
                      "limit" => limit,
                      "cursor" => cursor
                    })
        end

        # GET /audit/events/:id
        # @return [Hash] AuditEvent
        def get(event_id)
          @http.get("/audit/events/#{event_id}")
        end

        # GET /audit/events/:id/verify — server-side verify (pinned key).
        # @return [Hash]
        def verify(event_id)
          @http.get("/audit/events/#{event_id}/verify")
        end
      end

      # audit.orgs.*
      class Orgs
        def initialize(http)
          @http = http
        end

        # POST /audit/orgs
        def create(organization_id:, name: nil)
          body = { "organization_id" => organization_id }
          body["name"] = name if name
          @http.post("/audit/orgs", body)
        end

        # GET /audit/orgs
        def list
          @http.get("/audit/orgs")
        end

        # GET /audit/orgs/:org_id/integrity
        def integrity(organization_id)
          @http.get("/audit/orgs/#{organization_id}/integrity")
        end

        # PUT /audit/orgs/:org_id/retention
        def set_retention(organization_id, days)
          @http.put("/audit/orgs/#{organization_id}/retention", { "days" => days })
        end
      end

      # audit.streams.*
      class Streams
        def initialize(http)
          @http = http
        end

        # POST /audit/orgs/:org_id/streams — create a webhook stream.
        # The signing secret is returned ONCE.
        def create(organization_id, url:, type: "webhook")
          @http.post("/audit/orgs/#{organization_id}/streams", {
                       "type" => type,
                       "url" => url
                     })
        end

        # GET /audit/orgs/:org_id/streams
        def list(organization_id)
          @http.get("/audit/orgs/#{organization_id}/streams")
        end

        # DELETE /audit/orgs/:org_id/streams/:stream_id
        def delete(organization_id, stream_id)
          @http.delete("/audit/orgs/#{organization_id}/streams/#{stream_id}")
        end

        # POST /audit/orgs/:org_id/streams/:stream_id/test
        def test(organization_id, stream_id)
          @http.post("/audit/orgs/#{organization_id}/streams/#{stream_id}/test")
        end
      end

      # audit.portal_sessions.*
      class PortalSessions
        def initialize(http)
          @http = http
        end

        # POST /audit/portal_sessions — mint a one-time hosted-viewer link.
        def create(organization_id:, intent:, session_duration_seconds: nil,
                   link_duration_seconds: nil)
          body = { "organization_id" => organization_id, "intent" => intent }
          body["session_duration_seconds"] = session_duration_seconds unless session_duration_seconds.nil?
          body["link_duration_seconds"] = link_duration_seconds unless link_duration_seconds.nil?
          @http.post("/audit/portal_sessions", body)
        end
      end

      # audit.exports.*
      class Exports
        def initialize(http)
          @http = http
        end

        # POST /audit/exports — queue an async CSV/NDJSON export job.
        # @param format [String] "csv" or "ndjson"
        def create(organization_id:, format:, filters: nil)
          body = { "organization_id" => organization_id, "format" => format }
          body["filters"] = filters if filters
          @http.post("/audit/exports", body)
        end

        # GET /audit/exports/:id — poll a job.
        def get(export_id)
          @http.get("/audit/exports/#{export_id}")
        end
      end

      attr_reader :events, :orgs, :streams, :portal_sessions, :exports

      def initialize(http)
        @events = Events.new(http)
        @orgs = Orgs.new(http)
        @streams = Streams.new(http)
        @portal_sessions = PortalSessions.new(http)
        @exports = Exports.new(http)
      end
    end
  end
end
