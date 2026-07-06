# frozen_string_literal: true

require "spec_helper"
require "openssl"

# Whether this Ruby's OpenSSL can do Ed25519 (Ruby >= 3.0 with modern OpenSSL).
ED25519_KEYGEN_AVAILABLE = begin
  OpenSSL::PKey.generate_key("ED25519")
  true
rescue StandardError
  false
end

RSpec.describe Invoance::AuditVerify do
  describe ".ed25519_verify" do
    # A fixed, known-good test vector (message signed with a throwaway key).
    # Used so the assertion runs even where OpenSSL keygen is unavailable —
    # though verify itself still needs an Ed25519-capable OpenSSL.
    let(:vector) do
      {
        "pub" => "05bf3e299f412854be35ccf8c23867a9a6312f1154f6117a0404e6784c177660",
        "msg" => "696e766f616e63652d656432353531392d746573742d766563746f72",
        "sig" => "f2e3be817fe0f42d97de031bc43895296e527a37588879803946f6afb4f" \
                 "df58fb54629753c258e9ac0b5344061b1a76438dddca40cc348acb9ac4272d1647702"
      }
    end

    def h2b(hex)
      [hex].pack("H*")
    end

    it "never raises even on an OpenSSL that lacks Ed25519 (degrades to false)" do
      expect do
        described_class.ed25519_verify(h2b(vector["msg"]), h2b(vector["sig"]), h2b(vector["pub"]))
      end.not_to raise_error
    end

    context "when OpenSSL Ed25519 is available", if: ED25519_KEYGEN_AVAILABLE do
      it "returns true for a valid signature" do
        expect(described_class.ed25519_verify(
                 h2b(vector["msg"]), h2b(vector["sig"]), h2b(vector["pub"])
               )).to be(true)
      end

      it "returns false for a tampered message" do
        expect(described_class.ed25519_verify(
                 h2b(vector["msg"] + "00"), h2b(vector["sig"]), h2b(vector["pub"])
               )).to be(false)
      end
    end
  end

  describe ".verify_audit_event round-trip", if: ED25519_KEYGEN_AVAILABLE do
    it "signs a canonicalized event and verifies it through the SDK path" do
      signed_input = {
        "org_id" => "org_1", "event_id" => "evt_round", "seq" => 3,
        "ingested_at" => "2026-03-01T10:00:00.500Z", "action" => "doc.sign",
        "occurred_at" => "2026-03-01T10:00:00Z",
        "actor" => { "type" => "user", "id" => "u_7" }, "targets" => []
      }
      canon = Invoance::AuditCanonical.canonical_audit_bytes(signed_input)
      payload_hash = Invoance::AuditCanonical.payload_hash_hex(canon)

      priv = OpenSSL::PKey.generate_key("ED25519")
      # Extract the raw 32-byte public key portably (works across OpenSSL
      # bindings that lack #raw_public_key): last 32 bytes of the DER SPKI.
      raw_pub = priv.public_to_der[-32, 32].unpack1("H*")
      sig = priv.sign(nil, canon).unpack1("H*")

      event = {
        "id" => "evt_round", "org_id" => "org_1", "seq" => 3,
        "ingested_at" => "2026-03-01T10:00:00.500Z", "action" => "doc.sign",
        "occurred_at" => "2026-03-01T10:00:00Z",
        "actor" => { "type" => "user", "id" => "u_7" }, "targets" => [],
        "payload_hash" => payload_hash,
        "signature" => sig,
        "signing_public_key" => raw_pub
      }

      result = described_class.verify_audit_event(event)
      expect(result["valid"]).to be(true)
      expect(result["reason"]).to be_nil
      expect(result["payload_hash"]).to eq(payload_hash)
      expect(result["key_source"]).to eq("event")
    end

    it "flags a tampered payload_hash as a mismatch" do
      event = {
        "id" => "evt_x", "org_id" => "org_1", "seq" => 1,
        "ingested_at" => "2026-03-01T10:00:00Z", "action" => "a",
        "occurred_at" => "2026-03-01T10:00:00Z", "actor" => {}, "targets" => [],
        "payload_hash" => "0" * 64,
        "signature" => "ab" * 32,
        "signing_public_key" => "cd" * 32
      }
      result = described_class.verify_audit_event(event)
      expect(result["valid"]).to be(false)
      expect(result["reason"]).to eq("payload_hash_mismatch")
    end

    it "reports pinned key_source when a public key is passed" do
      event = {
        "id" => "evt_x", "org_id" => "org_1", "seq" => 1,
        "ingested_at" => "2026-03-01T10:00:00Z", "action" => "a",
        "occurred_at" => "2026-03-01T10:00:00Z", "actor" => {}, "targets" => []
      }
      result = described_class.verify_audit_event(event, public_key: "cd" * 32)
      expect(result["key_source"]).to eq("pinned")
    end
  end

  describe ".verify_audit_event reasons (no crypto needed)" do
    let(:base) do
      {
        "id" => "evt_x", "org_id" => "org_1", "seq" => 1,
        "ingested_at" => "2026-03-01T10:00:00Z", "action" => "a",
        "occurred_at" => "2026-03-01T10:00:00Z", "actor" => {}, "targets" => []
      }
    end

    it "returns no_public_key when the event has no key" do
      result = described_class.verify_audit_event(base)
      expect(result["valid"]).to be(false)
      expect(result["reason"]).to eq("no_public_key")
    end

    it "returns no_signature when a key is present but no signature" do
      result = described_class.verify_audit_event(base.merge("signing_public_key" => "cd" * 32))
      expect(result["reason"]).to eq("no_signature")
    end
  end
end
