# frozen_string_literal: true

require "digest"

require_relative "../validate"

module Invoance
  module Resources
    # Documents resource — client.documents.*
    class Documents
      # @param http [Invoance::Http]
      def initialize(http)
        @http = http
      end

      # POST /document/anchor — Anchor a document hash.
      #
      # @param document_hash [String] hex SHA-256 (validated)
      # @return [Hash] AnchorDocumentResponse
      def anchor(document_hash:, document_ref: nil, event_type: nil, original_bytes_b64: nil,
                 metadata: nil, trace_id: nil, idempotency_key: nil)
        Validate.assert_sha256_hex("document_hash", document_hash)
        body = { "document_hash" => document_hash }
        body["document_ref"] = document_ref unless document_ref.nil?
        body["event_type"] = event_type unless event_type.nil?
        body["original_bytes_b64"] = original_bytes_b64 unless original_bytes_b64.nil?
        body["metadata"] = metadata unless metadata.nil?
        body["trace_id"] = trace_id unless trace_id.nil?
        @http.post("/document/anchor", body, idempotency_key)
      end

      # Convenience helper — reads a file (path String or raw bytes String),
      # computes the SHA-256 hash, base64-encodes the bytes, then anchors.
      #
      # @param file [String] a filesystem path OR raw file bytes
      # @param is_path [Boolean] whether `file` is a path (default: true).
      #   When bytes are passed directly, set is_path: false.
      # @param skip_original [Boolean] omit uploading the original bytes
      # @return [Hash] AnchorDocumentResponse
      def anchor_file(file:, is_path: true, document_ref: nil, event_type: nil,
                      metadata: nil, trace_id: nil, idempotency_key: nil, skip_original: false)
        content =
          if is_path
            File.binread(file)
          else
            file.dup.force_encoding(Encoding::BINARY)
          end

        document_hash = Digest::SHA256.hexdigest(content)
        ref = document_ref || (is_path ? File.basename(file) : nil)
        # Strict Base64 (no line breaks) via stdlib pack — avoids depending on
        # the `base64` gem, which left Ruby's default gems in 3.4+.
        original_b64 = skip_original ? nil : [content].pack("m0")

        anchor(
          document_hash: document_hash,
          document_ref: ref,
          event_type: event_type,
          metadata: metadata,
          idempotency_key: idempotency_key,
          original_bytes_b64: original_b64,
          trace_id: trace_id
        )
      end

      # GET /document — Paginated document listing.
      # @return [Hash] ListDocumentsResponse
      def list(page: nil, limit: nil, date_from: nil, date_to: nil, document_ref: nil)
        @http.get("/document", {
                    "page" => page,
                    "limit" => limit,
                    "date_from" => date_from,
                    "date_to" => date_to,
                    "document_ref" => document_ref
                  })
      end

      # GET /document/:event_id — Retrieve a single document.
      # @return [Hash] DocumentEvent
      def get(event_id)
        @http.get("/document/#{event_id}")
      end

      # GET /document/:event_id/original — Download the original file.
      # @return [String] raw binary bytes
      def get_original(event_id)
        @http.get_bytes("/document/#{event_id}/original")
      end

      # POST /document/:event_id/verify — Hash verification.
      # @return [Hash] VerifyDocumentResponse
      def verify(event_id, document_hash:)
        Validate.assert_sha256_hex("document_hash", document_hash)
        @http.post("/document/#{event_id}/verify", { "document_hash" => document_hash })
      end
    end
  end
end
