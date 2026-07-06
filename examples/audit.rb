# frozen_string_literal: true

# Register an org, append a signed audit event, then verify it offline.
#
#   INVOANCE_API_KEY=inv_live_... ruby examples/audit.rb

require_relative "../lib/invoance"

client = Invoance::Client.new
org_id = "org_demo"

client.audit.orgs.create(organization_id: org_id, name: "Demo Corp")

event = client.audit.events.ingest(
  organization_id: org_id,
  action: "invoice.approved",
  actor: { "type" => "user", "id" => "u_1", "name" => "Ada" },
  targets: [{ "type" => "invoice", "id" => "inv_9" }],
  metadata: { "amount_cents" => 4200 }
)
event_id = event["id"] || event["event_id"]
puts "Appended audit event #{event_id}"

# Offline signature + hash verification (no trust in the server).
fetched = client.audit.events.get(event_id)
result = Invoance::AuditVerify.verify_audit_event(fetched)
puts "Offline verify — valid: #{result['valid']}, reason: #{result['reason'].inspect}"
puts "Recomputed payload_hash: #{result['payload_hash']}"
