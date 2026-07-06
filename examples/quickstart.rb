# frozen_string_literal: true

# Quick-start: ingest an event and read it back.
#
#   INVOANCE_API_KEY=inv_live_... ruby examples/quickstart.rb

require_relative "../lib/invoance"

client = Invoance::Client.new # reads INVOANCE_API_KEY / INVOANCE_BASE_URL

check = client.validate
abort "Invalid config: #{check['reason']}" unless check["valid"]
puts "Connected to #{check['base_url']}"

event = client.events.ingest(
  event_type: "user.login",
  payload: { "user_id" => "u_42", "ip" => "203.0.113.7" }
)
puts "Ingested event #{event['event_id']} at #{event['ingested_at']}"

fetched = client.events.get(event["event_id"])
puts "event_hash: #{fetched['event_hash']}"
