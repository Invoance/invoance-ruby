# frozen_string_literal: true

# Anchor an AI attestation and verify its Ed25519 signature client-side.
#
#   INVOANCE_API_KEY=inv_live_... ruby examples/attestations.rb

require_relative "../lib/invoance"

client = Invoance::Client.new

att = client.attestations.ingest(
  type: "chat.completion",
  input: { "prompt" => "Summarize the Q3 report." },
  output: { "text" => "Revenue up 12% YoY." },
  model_provider: "openai",
  model_name: "gpt-4o",
  model_version: "2026-01",
  subject: { user_id: "u_1", session_id: "s_9" }
)
puts "Attestation #{att['attestation_id']} — payload_hash #{att['payload_hash']}"

result = client.attestations.verify_signature(att["attestation_id"])
puts "Signature valid: #{result['valid']}"
puts "Reason: #{result['reason']}" if result["reason"]
