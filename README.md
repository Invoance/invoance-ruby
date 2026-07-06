# Invoance Ruby SDK

Official Ruby SDK for the [Invoance](https://invoance.com) compliance API —
cryptographic proof infrastructure for events, documents, AI attestations,
traces, and audit logs.

- **Synchronous** — methods return values and raise exceptions on error.
- **Zero runtime dependencies** — pure Ruby stdlib (`net/http`, `json`,
  `openssl`, `digest`).
- **Offline verification** — check Ed25519 signatures and recompute audit-log
  canonical hashes without trusting the server.

Requires **Ruby >= 3.0**.

## Installation

Add to your Gemfile:

```ruby
gem "invoance"
```

Then:

```console
$ bundle install
```

Or install directly:

```console
$ gem install invoance
```

## Quick start

```ruby
require "invoance"

# Reads INVOANCE_API_KEY and INVOANCE_BASE_URL from the environment.
client = Invoance::Client.new

# Or pass the key explicitly:
client = Invoance::Client.new(api_key: "inv_live_abc123")

# Ingest a compliance event
event = client.events.ingest(
  event_type: "user.login",
  payload: { "user_id" => "u_42" }
)
puts event["event_id"]

# Verify the API key / connectivity (never raises)
result = client.validate
raise "bad config: #{result["reason"]}" unless result["valid"]
```

Responses are plain Ruby `Hash`es with **string keys** matching the wire JSON
exactly — no symbolization.

## Configuration

```ruby
client = Invoance::Client.new(
  api_key: "inv_live_...",             # or ENV["INVOANCE_API_KEY"]
  base_url: "https://api.invoance.com", # or ENV["INVOANCE_BASE_URL"]
  api_version: "v1",
  timeout: 30,                          # seconds
  idempotency_key: nil,                 # default for mutating requests
  extra_headers: {}                     # merged into every request
)
```

## Resources

### Events

```ruby
client.events.ingest(event_type:, payload:, event_time: nil, trace_id: nil, idempotency_key: nil)
client.events.list(page: nil, limit: nil, date_from: nil, date_to: nil, event_type: nil)
client.events.get(event_id)
client.events.verify(event_id, payload_hash: nil, payload: nil) # provide exactly one
```

### Documents

```ruby
client.documents.anchor(document_hash:, document_ref: nil, event_type: nil,
                        original_bytes_b64: nil, metadata: nil, trace_id: nil,
                        idempotency_key: nil)

# Convenience: hash + base64 a file, then anchor.
client.documents.anchor_file(file: "./invoice.pdf", document_ref: "Invoice #1042")
# For raw bytes instead of a path:
client.documents.anchor_file(file: bytes, is_path: false, document_ref: "blob")

client.documents.list(...)
client.documents.get(event_id)
client.documents.get_original(event_id) # => raw binary String
client.documents.verify(event_id, document_hash:)
```

### AI Attestations

```ruby
client.attestations.ingest(
  type: "chat.completion",
  input: { "prompt" => "..." },
  output: { "text" => "..." },
  model_provider: "openai",
  model_name: "gpt-4o",
  model_version: "2026-01",
  subject: { user_id: "u_1", session_id: "s_9" } # optional
)

client.attestations.list(...)
client.attestations.get(id)
client.attestations.verify(id, content_hash:)
client.attestations.get_raw(id) # => Hash

# Client-side verification (no trust in the server):
client.attestations.verify_payload(id, raw_json_string_or_hash)
result = client.attestations.verify_signature(id)
result["valid"] # => true/false
```

> **Note:** for `verify_payload`, pass the raw JSON string exactly as shown in
> the dashboard's "Raw immutable record" viewer. Key order is preserved (not
> sorted) because the backend hashes with struct field order.

### Traces

```ruby
trace = client.traces.create(label: "Batch 2026-07")
client.traces.list(status: "open")
client.traces.get(trace_id, event_page: 1, event_limit: 50)
client.traces.seal(trace_id)
client.traces.proof(trace_id)         # => Hash
client.traces.proof_pdf(trace_id)     # => raw binary PDF String
client.traces.delete(trace_id)
```

### Audit Logs

```ruby
client.audit.orgs.create(organization_id: "org_1", name: "Acme")
client.audit.events.ingest(
  organization_id: "org_1",
  action: "invoice.approved",
  actor: { "type" => "user", "id" => "u_1" },
  targets: [{ "type" => "invoice", "id" => "inv_9" }]
)
client.audit.events.list(organization_id: "org_1", limit: 100)
client.audit.streams.create("org_1", url: "https://siem.example/hook")
client.audit.portal_sessions.create(organization_id: "org_1", intent: "viewer")
client.audit.exports.create(organization_id: "org_1", format: "csv")
```

Offline verify an audit event returned by the API:

```ruby
event = client.audit.events.get("evt_123")
result = Invoance::AuditVerify.verify_audit_event(event)
# => { "valid" => true, "reason" => nil, "payload_hash" => "...", "key_source" => "event" }

# Pin against the tenant's registered key for a real tamper guarantee:
Invoance::AuditVerify.verify_audit_event(event, public_key: registered_hex_key)
```

## Error handling

Everything the SDK raises inherits from `Invoance::Error`:

```ruby
begin
  client.events.ingest(event_type: "user.login", payload: {})
rescue Invoance::QuotaExceededError => e
  puts "rate limited, retry after #{e.retry_after_seconds}s"
rescue Invoance::AuthenticationError
  puts "check INVOANCE_API_KEY"
rescue Invoance::Error => e
  puts "Invoance error: #{e.message} (status #{e.status_code})"
end
```

Every error exposes `status_code`, `error_code`, `body`,
`retry_after_seconds`, and `request_context`.

## Development

```console
$ bundle install
$ bundle exec rspec
```

## License

MIT — see [LICENSE](LICENSE).
