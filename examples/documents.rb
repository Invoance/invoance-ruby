# frozen_string_literal: true

# Anchor a document and verify it. Pass a file path as ARGV[0].
#
#   INVOANCE_API_KEY=inv_live_... ruby examples/documents.rb ./invoice.pdf

require_relative "../lib/invoance"

path = ARGV[0] || abort("usage: ruby examples/documents.rb <file>")
client = Invoance::Client.new

anchored = client.documents.anchor_file(file: path, document_ref: File.basename(path))
puts "Anchored #{anchored['document_hash']} as event #{anchored['event_id']}"

verify = client.documents.verify(anchored["event_id"], document_hash: anchored["document_hash"])
puts "Verification match_result: #{verify['match_result']}"

original = client.documents.get_original(anchored["event_id"])
puts "Downloaded #{original.bytesize} bytes of the original file"
