# frozen_string_literal: true

# Create a trace, attach events, seal it, and fetch the proof bundle.
#
#   INVOANCE_API_KEY=inv_live_... ruby examples/traces.rb

require_relative "../lib/invoance"

client = Invoance::Client.new

trace = client.traces.create(label: "Nightly batch #{Time.now.utc.iso8601}")
trace_id = trace["trace_id"]
puts "Created trace #{trace_id}"

client.events.ingest(
  event_type: "batch.record",
  payload: { "row" => 1 },
  trace_id: trace_id
)

seal = client.traces.seal(trace_id)
puts "Seal status: #{seal['status']} — #{seal['message']}"

# Sealing is async; in real code poll traces.get until status == "sealed"
# before requesting the proof bundle.
detail = client.traces.get(trace_id)
puts "Trace status: #{detail['status']}, events: #{detail['event_count']}"
