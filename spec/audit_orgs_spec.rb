# frozen_string_literal: true

require "spec_helper"

RSpec.describe "audit.orgs lifecycle (WebMock)" do
  let(:client) { Invoance::Client.new(api_key: "inv_test_key", base_url: "https://api.test") }

  let(:org_json) do
    {
      "id" => "aorg_1",
      "organization_id" => "org_1",
      "external_id" => "org_1",
      "name" => "Acme",
      "retention_days" => 365,
      "created_at" => "2026-01-01T00:00:00Z",
      "archived_at" => nil
    }
  end

  describe "orgs.update" do
    it "PATCHes the new name and parses the full org response" do
      stub = stub_request(:patch, "https://api.test/v1/audit/orgs/aorg_1")
             .with(
               headers: { "Authorization" => "Bearer inv_test_key" },
               body: { "name" => "New Name" }
             )
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate(org_json.merge("name" => "New Name"))
             )

      resp = client.audit.orgs.update("aorg_1", name: "New Name")
      expect(stub).to have_been_requested
      expect(resp["name"]).to eq("New Name")
      expect(resp["archived_at"]).to be_nil
    end

    it "sends JSON null to clear the name" do
      stub = stub_request(:patch, "https://api.test/v1/audit/orgs/aorg_1")
             .with(body: '{"name":null}')
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate(org_json.merge("name" => nil))
             )

      resp = client.audit.orgs.update("aorg_1", name: nil)
      expect(stub).to have_been_requested
      expect(resp["name"]).to be_nil
    end

    it "accepts the customer organization_id in the path" do
      stub = stub_request(:patch, "https://api.test/v1/audit/orgs/org_1")
             .with(body: { "name" => "Acme" })
             .to_return(status: 200, body: JSON.generate(org_json))

      client.audit.orgs.update("org_1", name: "Acme")
      expect(stub).to have_been_requested
    end
  end

  describe "orgs.archive" do
    it "POSTs with no body and returns the org with archived_at set" do
      stub = stub_request(:post, "https://api.test/v1/audit/orgs/aorg_1/archive")
             .with { |req| req.body.nil? || req.body.empty? }
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate(org_json.merge("archived_at" => "2026-07-13T00:00:00Z"))
             )

      resp = client.audit.orgs.archive("aorg_1")
      expect(stub).to have_been_requested
      expect(resp["archived_at"]).to eq("2026-07-13T00:00:00Z")
    end
  end

  describe "orgs.unarchive" do
    it "POSTs with no body and returns the org with archived_at null" do
      stub = stub_request(:post, "https://api.test/v1/audit/orgs/aorg_1/unarchive")
             .with { |req| req.body.nil? || req.body.empty? }
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate(org_json)
             )

      resp = client.audit.orgs.unarchive("aorg_1")
      expect(stub).to have_been_requested
      expect(resp["archived_at"]).to be_nil
    end
  end

  describe "orgs.delete" do
    it "DELETEs and parses the deletion receipt" do
      stub = stub_request(:delete, "https://api.test/v1/audit/orgs/aorg_1")
             .to_return(
               status: 200,
               headers: { "Content-Type" => "application/json" },
               body: JSON.generate("deleted" => true, "id" => "aorg_1")
             )

      resp = client.audit.orgs.delete("aorg_1")
      expect(stub).to have_been_requested
      expect(resp).to eq("deleted" => true, "id" => "aorg_1")
    end

    it "raises ConflictError with org_not_deletable on 409" do
      stub_request(:delete, "https://api.test/v1/audit/orgs/aorg_1")
        .to_return(
          status: 409,
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate("error" => "org_not_deletable")
        )

      expect { client.audit.orgs.delete("aorg_1") }
        .to raise_error(Invoance::ConflictError) { |e|
          expect(e.status_code).to eq(409)
          expect(e.error_code).to eq("org_not_deletable")
        }
    end
  end

  describe "orgs.list" do
    it "sends no query params by default (archived excluded server-side)" do
      stub = stub_request(:get, "https://api.test/v1/audit/orgs")
             .to_return(status: 200, body: JSON.generate("orgs" => [org_json]))

      resp = client.audit.orgs.list
      expect(stub).to have_been_requested
      expect(resp["orgs"].first["archived_at"]).to be_nil
    end

    it "passes include_archived=true as a query param" do
      stub = stub_request(:get, "https://api.test/v1/audit/orgs")
             .with(query: { "include_archived" => "true" })
             .to_return(status: 200, body: JSON.generate("orgs" => []))

      client.audit.orgs.list(include_archived: true)
      expect(stub).to have_been_requested
    end
  end
end
