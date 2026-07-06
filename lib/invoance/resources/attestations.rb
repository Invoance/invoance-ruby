# frozen_string_literal: true

require "json"
require "digest"

require_relative "../validate"
require_relative "../audit_verify"

module Invoance
  module Resources
    # AI Attestations resource — client.attestations.*
    class Attestations
      # @param http [Invoance::Http]
      def initialize(http)
        @http = http
      end

      # POST /ai/attestations — Anchor an AI attestation.
      #
      # The body is NESTED and field order matters for the server's hashing
      # (type, payload, context, subject) — do not reorder.
      #
      # @param type [String]
      # @param input [Object]
      # @param output [Object]
      # @param model_provider [String, nil]
      # @param model_name [String, nil]
      # @param model_version [String, nil]
      # @param subject [Hash, nil] user_id/session_id + arbitrary extra keys
      # @param trace_id [String, nil]
      # @param idempotency_key [String, nil]
      # @return [Hash] IngestAttestationResponse
      def ingest(type:, input:, output:, model_provider: nil, model_name: nil,
                 model_version: nil, subject: nil, trace_id: nil, idempotency_key: nil)
        body = {
          "type" => type,
          "payload" => { "input" => input, "output" => output },
          "context" => {
            "model_provider" => model_provider,
            "model_name" => model_name,
            "model_version" => model_version
          }
        }

        unless subject.nil?
          s = symbolize_subject(subject)
          user_id = s.delete(:user_id)
          session_id = s.delete(:session_id)
          subj = {}
          subj["user_id"] = user_id unless user_id.nil?
          subj["session_id"] = session_id unless session_id.nil?
          # Pass through any remaining extra keys, preserving their string form.
          s.each { |k, v| subj[k.to_s] = v }
          body["subject"] = subj unless subj.empty?
        end

        body["trace_id"] = trace_id unless trace_id.nil?

        @http.post("/ai/attestations", body, idempotency_key)
      end

      # GET /ai/attestations — Paginated attestation listing.
      # @return [Hash] ListAttestationsResponse
      def list(page: nil, limit: nil, date_from: nil, date_to: nil,
               attestation_type: nil, model_provider: nil)
        @http.get("/ai/attestations", {
                    "page" => page,
                    "limit" => limit,
                    "date_from" => date_from,
                    "date_to" => date_to,
                    "attestation_type" => attestation_type,
                    "model_provider" => model_provider
                  })
      end

      # GET /ai/attestations/:id — Retrieve a single attestation.
      # @return [Hash] AiAttestation
      def get(attestation_id)
        @http.get("/ai/attestations/#{attestation_id}")
      end

      # POST /ai/attestations/:id/verify — Hash verification.
      # @return [Hash] VerifyAttestationResponse
      def verify(attestation_id, content_hash:)
        Validate.assert_sha256_hex("content_hash", content_hash)
        @http.post("/ai/attestations/#{attestation_id}/verify",
                   { "content_hash" => content_hash })
      end

      # GET /ai/attestations/:id/raw — Retrieve the canonical JSON payload.
      # @return [Hash]
      def get_raw(attestation_id)
        @http.get_raw("/ai/attestations/#{attestation_id}/raw")
      end

      # Verify by raw payload — hashes client-side, then calls verify.
      #
      # Accepts the canonical JSON stored in Invoance as a raw String or a
      # Hash. Key ORDER is PRESERVED (not sorted) because the backend hashes
      # using serde_json struct field order (type, payload, context, subject).
      #
      # * String input: JSON.parse preserves object key order into an
      #   insertion-ordered Hash, and JSON.generate preserves it — giving
      #   compact order-preserving JSON (= JS JSON.stringify(JSON.parse(s))).
      # * Hash input: JSON.generate preserves insertion order — pass the keys
      #   already in the correct order.
      #
      # @param attestation_id [String]
      # @param payload [String, Hash]
      # @return [Hash] VerifyAttestationResponse
      def verify_payload(attestation_id, payload)
        canonical =
          if payload.is_a?(String)
            JSON.generate(JSON.parse(payload))
          else
            JSON.generate(payload)
          end

        content_hash = Digest::SHA256.hexdigest(canonical)
        verify(attestation_id, content_hash: content_hash)
      end

      # Verify the Ed25519 signature of an attestation — fully client-side.
      #
      # Fetches the attestation, then verifies the signature against
      # signed_payload using public_key. Requires no trust in the server.
      #
      # @param attestation_id [String]
      # @return [Hash] { "valid" =>, "reason" =>, "attestation" =>, "signed_data" => }
      def verify_signature(attestation_id)
        att = get(attestation_id)

        signed_payload_bytes = hex_to_bytes(att["signed_payload"].to_s)
        signature_bytes = hex_to_bytes(att["signature"].to_s)
        public_key_bytes = hex_to_bytes(att["public_key"].to_s)

        valid = false
        reason = nil
        begin
          valid = AuditVerify.ed25519_verify(signed_payload_bytes, signature_bytes, public_key_bytes)
          reason = "Signature does not match signed_payload + public_key" unless valid
        rescue StandardError => e
          valid = false
          reason = e.message
        end

        signed_data =
          begin
            JSON.parse(signed_payload_bytes.dup.force_encoding(Encoding::UTF_8))
          rescue JSON::ParserError
            nil
          end

        { "valid" => valid, "reason" => reason, "attestation" => att, "signed_data" => signed_data }
      end

      private

      def hex_to_bytes(hex)
        [hex].pack("H*")
      end

      def symbolize_subject(subject)
        subject.each_with_object({}) do |(k, v), out|
          key = k.is_a?(String) ? k.to_sym : k
          out[key] = v
        end
      end
    end
  end
end
