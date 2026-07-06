# frozen_string_literal: true

require "spec_helper"

RSpec.describe Invoance::AuditCanonical do
  describe ".normalize_ts" do
    it "truncates fractional seconds to exactly 3 digits (millis, no rounding)" do
      expect(described_class.normalize_ts("2026-01-02T03:04:05.678901Z"))
        .to eq("2026-01-02T03:04:05.678Z")
      expect(described_class.normalize_ts("2026-01-02T03:04:05.999999Z"))
        .to eq("2026-01-02T03:04:05.999Z")
    end

    it "pads fractional seconds under 3 digits" do
      expect(described_class.normalize_ts("2026-01-02T03:04:05.12+00:00"))
        .to eq("2026-01-02T03:04:05.120Z")
    end

    it "defaults missing fractional seconds to .000" do
      expect(described_class.normalize_ts("2026-01-02T03:04:05Z"))
        .to eq("2026-01-02T03:04:05.000Z")
    end

    it "converts a negative UTC offset to Z" do
      expect(described_class.normalize_ts("2026-01-02T05:04:05-02:30"))
        .to eq("2026-01-02T07:34:05.000Z")
    end

    it "converts a positive UTC offset to Z" do
      expect(described_class.normalize_ts("2026-01-02T05:04:05+05:00"))
        .to eq("2026-01-02T00:04:05.000Z")
    end

    it "raises on a non-RFC3339 string" do
      expect { described_class.normalize_ts("not-a-date") }.to raise_error(ArgumentError)
    end
  end

  describe ".canonical_audit_bytes (golden vector)" do
    let(:event) do
      {
        "org_id" => "org_123",
        "event_id" => "evt_abc",
        "seq" => 7,
        "ingested_at" => "2026-01-02T03:04:05.678901Z",
        "action" => "user.login",
        "occurred_at" => "2026-01-02T03:04:05.12+00:00",
        "actor" => { "type" => "user", "id" => "u_1", "name" => "Ada" },
        "targets" => [{ "type" => "doc", "id" => "d_9" }],
        "metadata" => { "z" => 1, "a" => 2 },
        "context" => nil # stripped
      }
    end

    let(:expected_canonical) do
      '{"action":"user.login","actor":{"id":"u_1","name":"Ada","type":"user"},' \
      '"event_id":"evt_abc","ingested_at":"2026-01-02T03:04:05.678Z",' \
      '"metadata":{"a":2,"z":1},"occurred_at":"2026-01-02T03:04:05.120Z",' \
      '"org_id":"org_123","schema_id":"invoance.audit/1","seq":7,' \
      '"targets":[{"id":"d_9","type":"doc"}]}'
    end

    it "produces byte-identical canonical JSON (deep-sorted, null-stripped, forced schema_id)" do
      expect(described_class.canonical_audit_bytes(event)).to eq(expected_canonical)
    end

    it "computes the golden payload hash" do
      canon = described_class.canonical_audit_bytes(event)
      expect(described_class.payload_hash_hex(canon))
        .to eq("e0ad07db718c1d0fe04e59d1c6c66a93a8d6efde9adf96da9039ec8dc9d5ae30")
    end

    it "does NOT escape forward slashes (matches JS JSON.stringify)" do
      canon = described_class.canonical_audit_bytes(event)
      expect(canon).to include("invoance.audit/1")
      expect(canon).not_to include('invoance.audit\\/1')
    end
  end

  describe "required-field enforcement" do
    it "raises when a required field is missing" do
      expect do
        described_class.canonical_audit_bytes(
          "org_id" => "o", "event_id" => "e", "seq" => 1,
          "ingested_at" => "2026-01-01T00:00:00Z", "action" => "a",
          "occurred_at" => "2026-01-01T00:00:00Z", "actor" => {}
          # targets missing
        )
      end.to raise_error(ArgumentError, /missing required field: targets/)
    end
  end
end
