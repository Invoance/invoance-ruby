# frozen_string_literal: true

require "json"
require "openssl"

require_relative "audit_canonical"

module Invoance
  # Offline, client-side signature verification for audit events.
  #
  # Reconstructs the canonical signed bytes from an event returned by the API
  # and checks the Ed25519 signature using stdlib OpenSSL (no external
  # dependency, matching this SDK's zero-dependency design).
  #
  # Trust note: by default this verifies against the key embedded in the event
  # (event["signing_public_key"]), which proves the payload is internally
  # consistent with that key. For a real tamper guarantee, pass public_key =
  # the tenant's registered key (the server pins it and never trusts the row's
  # key).
  #
  # Ed25519 requires Ruby's OpenSSL to support Ed25519 (Ruby >= 3.0 with a
  # modern OpenSSL). On older stacks the verify degrades to an invalid result
  # with a descriptive reason rather than crashing. If you need to support
  # such stacks, the `ed25519` gem is a drop-in alternative — but this SDK
  # stays dependency-free.
  module AuditVerify
    # DER SPKI prefix for a raw 32-byte Ed25519 public key (RFC 8410).
    SPKI_ED25519_PREFIX = ["302a300506032b6570032100"].pack("H*").freeze

    module_function

    # Ed25519-verify a raw message with a raw 32-byte public key.
    # Returns true/false; never raises (OpenSSL errors → false).
    #
    # @param message [String] binary message bytes
    # @param signature [String] binary signature bytes
    # @param pubkey [String] raw 32-byte public key
    # @return [Boolean]
    def ed25519_verify(message, signature, pubkey)
      der = SPKI_ED25519_PREFIX + pubkey.b
      pkey = OpenSSL::PKey.read(der)
      # nil digest for Ed25519 (single-shot, no separate hash).
      pkey.verify(nil, signature.b, message.b)
    rescue StandardError, OpenSSL::OpenSSLError
      false
    end

    # Hex-decode a hex string into a binary String.
    # @api private
    def hex_to_bytes(hex)
      [hex].pack("H*")
    end

    # Verify one audit event's signature offline.
    #
    # @param event [Hash] string-keyed event as returned by the API
    # @param public_key [String, nil] hex-encoded pinned key to verify against
    # @return [Hash] { "valid" =>, "reason" =>, "payload_hash" =>, "key_source" => }
    def verify_audit_event(event, public_key: nil)
      key_source = public_key.nil? ? "event" : "pinned"
      e = stringify(event)

      signed_input = {
        "org_id" => e["org_id"],
        "event_id" => (e["id"].nil? ? e["event_id"] : e["id"]),
        "seq" => e["seq"],
        "ingested_at" => e["ingested_at"],
        "action" => e["action"],
        "occurred_at" => e["occurred_at"],
        "actor" => e["actor"],
        "targets" => e["targets"]
      }
      signed_input["context"] = e["context"] unless e["context"].nil?
      signed_input["metadata"] = e["metadata"] unless e["metadata"].nil?

      begin
        canonical = AuditCanonical.canonical_audit_bytes(signed_input)
      rescue StandardError
        return result(false, "canonicalization_failed", "", key_source)
      end

      recomputed = AuditCanonical.payload_hash_hex(canonical)
      if !e["payload_hash"].nil? && e["payload_hash"] != recomputed
        return result(false, "payload_hash_mismatch", recomputed, key_source)
      end

      key = public_key.nil? ? e["signing_public_key"] : public_key
      return result(false, "no_public_key", recomputed, key_source) if key.nil? || key == ""

      sig = e["signature"]
      return result(false, "no_signature", recomputed, key_source) if sig.nil? || sig == ""

      sig_bytes = sig.is_a?(String) ? hex_to_bytes(sig) : sig
      key_bytes = key.is_a?(String) ? hex_to_bytes(key) : key
      ok = ed25519_verify(canonical, sig_bytes, key_bytes)

      if ok
        result(true, nil, recomputed, key_source)
      else
        result(false, "signature_invalid", recomputed, key_source)
      end
    end

    # @api private
    def result(valid, reason, payload_hash, key_source)
      {
        "valid" => valid,
        "reason" => reason,
        "payload_hash" => payload_hash,
        "key_source" => key_source
      }
    end

    # @api private
    def stringify(hash)
      return {} unless hash.is_a?(Hash)

      hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
    end
  end
end
