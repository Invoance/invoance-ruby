# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HTTP round-trips (WebMock)" do
  let(:client) { Invoance::Client.new(api_key: "inv_test_key", base_url: "https://api.test") }

  describe "events.ingest" do
    it "POSTs the correct wire body, headers, and URL and parses the response" do
      stub = stub_request(:post, "https://api.test/v1/events")
             .with(
               headers: {
                 "Authorization" => "Bearer inv_test_key",
                 "Content-Type" => "application/json",
                 "Accept" => "application/json",
                 "User-Agent" => "invoance-ruby/#{Invoance::VERSION}",
                 "Idempotency-Key" => "idem-123"
               },
               body: {
                 "event_type" => "user.login",
                 "payload" => { "user_id" => "u_42" },
                 "trace_id" => "tr_1"
               }
             )
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate("event_id" => "evt_1", "ingested_at" => "2026-01-01T00:00:00Z")
             )

      resp = client.events.ingest(
        event_type: "user.login",
        payload: { "user_id" => "u_42" },
        trace_id: "tr_1",
        idempotency_key: "idem-123"
      )

      expect(stub).to have_been_requested
      expect(resp).to eq("event_id" => "evt_1", "ingested_at" => "2026-01-01T00:00:00Z")
      expect(resp["event_id"]).to eq("evt_1")
    end

    it "raises QuotaExceededError with retry_after_seconds on 429" do
      stub_request(:post, "https://api.test/v1/events")
        .to_return(
          status: 429,
          headers: { "Retry-After" => "30", "Content-Type" => "application/json" },
          body: JSON.generate("error" => "rate_limited")
        )

      expect do
        client.events.ingest(event_type: "x", payload: {})
      end.to raise_error(Invoance::QuotaExceededError) { |e|
        expect(e.status_code).to eq(429)
        expect(e.error_code).to eq("rate_limited")
        expect(e.retry_after_seconds).to eq(30.0)
      }
    end
  end

  describe "events.verify client-side validation" do
    it "raises ValidationError when neither payload_hash nor payload is given" do
      expect { client.events.verify("evt_1") }
        .to raise_error(Invoance::ValidationError, /either `payload_hash` or `payload`/)
    end

    it "raises ValidationError on a malformed payload_hash before any HTTP call" do
      expect { client.events.verify("evt_1", payload_hash: "nothex") }
        .to raise_error(Invoance::ValidationError)
      expect(a_request(:post, //)).not_to have_been_made
    end
  end

  describe "documents.get_original" do
    it "returns raw binary bytes with octet-stream Accept" do
      stub = stub_request(:get, "https://api.test/v1/document/evt_1/original")
             .with(headers: { "Accept" => "application/octet-stream" })
             .to_return(status: 200, body: "\x89PNG\r\n".b)

      bytes = client.documents.get_original("evt_1")
      expect(stub).to have_been_requested
      expect(bytes.encoding).to eq(Encoding::BINARY)
      expect(bytes).to eq("\x89PNG\r\n".b)
    end
  end

  describe "list query params" do
    it "skips nil params and stringifies the rest" do
      stub = stub_request(:get, "https://api.test/v1/events")
             .with(query: { "limit" => "5", "event_type" => "user.login" })
             .to_return(status: 200, body: JSON.generate("events" => [], "total" => 0))

      client.events.list(limit: 5, event_type: "user.login")
      expect(stub).to have_been_requested
    end
  end

  describe "client.validate" do
    let(:me_body) do
      {
        "valid" => true,
        "organization" => {
          "id" => "org_1", "name" => "Acme", "issuer_name" => "Acme Corp",
          "primary_domain" => "acme.test", "domain_verified" => true,
          "plan_tier" => "growth"
        },
        "tenant" => { "id" => "ten_1", "name" => "Acme" },
        "api_key" => {
          "id" => "key_1", "key_prefix" => "inv_test", "key_last4" => "_key",
          "scopes" => ["audit:read", "audit:write"],
          "created_at" => "2026-01-01T00:00:00Z"
        },
        "limits" => { "rate_limit_per_sec" => 50 }
      }
    end

    it "returns valid:true on 200 from GET /v1/me" do
      stub = stub_request(:get, "https://api.test/v1/me")
             .to_return(status: 200, body: JSON.generate(me_body))
      expect(client.validate).to eq(
        "valid" => true, "reason" => nil, "base_url" => "https://api.test"
      )
      expect(stub).to have_been_requested
    end

    it "validates a key with only audit:* scopes (no events probe)" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(status: 200, body: JSON.generate(me_body))
      result = client.validate
      expect(result["valid"]).to be(true)
      expect(result["reason"]).to be_nil
      expect(a_request(:get, %r{/v1/events})).not_to have_been_made
    end

    it "classifies 401 as invalid without raising" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(status: 401, body: JSON.generate("error" => "invalid_api_key"))
      result = client.validate
      expect(result["valid"]).to be(false)
      expect(result["reason"]).to match(/Authentication failed/)
    end

    it "treats 403 (IP access rules) as authenticated-but-blocked (valid:true)" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(status: 403, body: JSON.generate("error" => "forbidden"))
      result = client.validate
      expect(result["valid"]).to be(true)
      expect(result["reason"]).to match(/IP access rules/)
    end
  end

  describe "client.me" do
    it "GETs /v1/me and returns the parsed body untouched" do
      body = { "valid" => true, "tenant" => { "id" => "ten_1", "name" => "Acme" } }
      stub = stub_request(:get, "https://api.test/v1/me")
             .with(headers: { "Authorization" => "Bearer inv_test_key" })
             .to_return(status: 200, body: JSON.generate(body))
      expect(client.me).to eq(body)
      expect(stub).to have_been_requested
    end

    it "raises AuthenticationError on 401 (unlike validate)" do
      stub_request(:get, "https://api.test/v1/me")
        .to_return(status: 401, body: JSON.generate("error" => "invalid_api_key"))
      expect { client.me }.to raise_error(Invoance::AuthenticationError)
    end
  end
end

RSpec.describe "attestations.verify_payload" do
  let(:client) { Invoance::Client.new(api_key: "k", base_url: "https://api.test") }

  it "preserves key order from a raw JSON string and hashes the compact form" do
    raw = '{ "type": "chat", "payload": {"input":"hi","output":"yo"}, "context": {} }'
    compact = JSON.generate(JSON.parse(raw))
    expected_hash = Digest::SHA256.hexdigest(compact)

    stub = stub_request(:post, "https://api.test/v1/ai/attestations/att_1/verify")
           .with(body: { "content_hash" => expected_hash })
           .to_return(status: 200, body: JSON.generate("attestation_id" => "att_1"))

    resp = client.attestations.verify_payload("att_1", raw)
    expect(stub).to have_been_requested
    expect(resp["attestation_id"]).to eq("att_1")
  end
end
