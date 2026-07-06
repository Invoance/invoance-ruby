# frozen_string_literal: true

require "spec_helper"

RSpec.describe Invoance::Validate do
  describe ".assert_sha256_hex" do
    it "accepts a valid 64-char lowercase hex digest" do
      expect { described_class.assert_sha256_hex("h", "a" * 64) }.not_to raise_error
      expect { described_class.assert_sha256_hex("h", "0123456789abcdef" * 4) }.not_to raise_error
    end

    it "rejects a non-string" do
      expect { described_class.assert_sha256_hex("h", 123) }
        .to raise_error(Invoance::ValidationError, /must be a string/)
    end

    it "rejects a wrong length" do
      expect { described_class.assert_sha256_hex("h", "abc") }
        .to raise_error(Invoance::ValidationError, /64 hex chars/)
    end

    it "rejects uppercase / non-hex characters" do
      expect { described_class.assert_sha256_hex("h", "A" * 64) }
        .to raise_error(Invoance::ValidationError, /lowercase hex/)
      expect { described_class.assert_sha256_hex("h", "g" * 64) }
        .to raise_error(Invoance::ValidationError, /lowercase hex/)
    end
  end
end

RSpec.describe "Invoance::Resources.content_idempotency_key" do
  it "is stable regardless of input key order" do
    a = { "b" => 1, "a" => { "y" => 2, "x" => [3, 2, 1] } }
    b = { "a" => { "x" => [3, 2, 1], "y" => 2 }, "b" => 1 }
    expect(Invoance::Resources.content_idempotency_key(a))
      .to eq(Invoance::Resources.content_idempotency_key(b))
  end

  it "is prefixed with idem_ and a 64-char hex digest" do
    key = Invoance::Resources.content_idempotency_key("x" => 1)
    expect(key).to match(/\Aidem_[0-9a-f]{64}\z/)
  end

  it "matches the cross-SDK golden value" do
    body = {
      "organization_id" => "org_1", "action" => "a.b",
      "occurred_at" => "2026-01-01T00:00:00Z",
      "actor" => { "id" => "x", "type" => "user" }, "targets" => [],
      "metadata" => { "z" => 1, "a" => [3, 2, 1] }
    }
    expect(Invoance::Resources.content_idempotency_key(body))
      .to eq("idem_6a8f669ea9938a2ef01a5bc378636e641c92eb3f493c4dd7323029d20b0a9db1")
  end
end
