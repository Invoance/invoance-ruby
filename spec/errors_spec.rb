# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Invoance error mapping" do
  describe "Invoance.throw_for_status" do
    it "is a no-op on 2xx" do
      expect { Invoance.throw_for_status(200, { "ok" => true }) }.not_to raise_error
      expect { Invoance.throw_for_status(204, nil) }.not_to raise_error
    end

    {
      400 => Invoance::ValidationError,
      401 => Invoance::AuthenticationError,
      403 => Invoance::ForbiddenError,
      404 => Invoance::NotFoundError,
      409 => Invoance::ConflictError,
      429 => Invoance::QuotaExceededError,
      500 => Invoance::ServerError,
      502 => Invoance::ServerError,
      503 => Invoance::ServerError
    }.each do |status, klass|
      it "maps #{status} to #{klass}" do
        expect { Invoance.throw_for_status(status, { "error" => "boom" }) }
          .to raise_error(klass)
      end
    end

    it "maps an unmapped 4xx to the base Error" do
      expect { Invoance.throw_for_status(418, {}) }
        .to raise_error(Invoance::Error) { |e| expect(e.class).to eq(Invoance::Error) }
    end

    it "populates status_code, error_code and body" do
      Invoance.throw_for_status(404, { "error" => "not_found", "message" => "nope" },
                                request_context: { method: "GET", path: "/x" })
    rescue Invoance::NotFoundError => e
      expect(e.status_code).to eq(404)
      expect(e.error_code).to eq("not_found")
      expect(e.message).to eq("nope")
      expect(e.body).to eq({ "error" => "not_found", "message" => "nope" })
      expect(e.request_context).to eq({ method: "GET", path: "/x" })
    end

    it "defaults error_code to 'unknown' and builds a no-body message" do
      Invoance.throw_for_status(500, nil, request_context: { method: "POST", path: "/y" })
    rescue Invoance::ServerError => e
      expect(e.error_code).to eq("unknown")
      expect(e.message).to eq("HTTP 500 on POST /y (no response body)")
    end

    it "builds a rate-limited message for 429 with retry_after_seconds" do
      Invoance.throw_for_status(429, nil,
                                request_context: { method: "POST", path: "/z" },
                                retry_after_seconds: 12)
    rescue Invoance::QuotaExceededError => e
      expect(e.message).to eq("HTTP 429 on POST /z — rate limited, retry after 12s")
      expect(e.retry_after_seconds).to eq(12)
    end
  end

  it "all subclasses inherit from Invoance::Error" do
    [Invoance::AuthenticationError, Invoance::ForbiddenError, Invoance::NotFoundError,
     Invoance::ValidationError, Invoance::ConflictError, Invoance::QuotaExceededError,
     Invoance::ServerError, Invoance::NetworkError, Invoance::TimeoutError].each do |k|
      expect(k.ancestors).to include(Invoance::Error)
    end
  end
end
