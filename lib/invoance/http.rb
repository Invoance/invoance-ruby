# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "time"
require "openssl"

require_relative "errors"
require_relative "version"

module Invoance
  # Low-level HTTP transport using stdlib net/http. Zero external
  # dependencies. Network-level failures are raised as {Invoance::Error}
  # subclasses (NetworkError / TimeoutError) so a single rescue is
  # exhaustive.
  #
  # @api private
  class Http
    # @param config [Invoance::Config]
    def initialize(config)
      @config = config
      @base_headers = {
        "Authorization" => "Bearer #{config.api_key}",
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "User-Agent" => "invoance-ruby/#{Invoance::VERSION}"
      }.merge(config.extra_headers)
    end

    # GET returning parsed JSON (Hash with string keys).
    def get(path, params = nil)
      uri = build_uri(path, params)
      ctx = { method: "GET", path: path }
      resp = do_request(Net::HTTP::Get.new(uri), uri, ctx, headers: @base_headers)
      handle(resp, ctx)
    end

    # POST returning parsed JSON. Sends Idempotency-Key when available.
    def post(path, body = nil, idempotency_key = nil)
      uri = build_uri(path)
      ctx = { method: "POST", path: path }
      headers = @base_headers.dup
      idem = idempotency_key || @config.idempotency_key
      headers["Idempotency-Key"] = idem if idem
      req = Net::HTTP::Post.new(uri)
      req.body = JSON.generate(body) unless body.nil?
      resp = do_request(req, uri, ctx, headers: headers)
      handle(resp, ctx)
    end

    # PUT returning parsed JSON.
    def put(path, body = nil)
      uri = build_uri(path)
      ctx = { method: "PUT", path: path }
      req = Net::HTTP::Put.new(uri)
      req.body = JSON.generate(body) unless body.nil?
      resp = do_request(req, uri, ctx, headers: @base_headers)
      handle(resp, ctx)
    end

    # DELETE returning parsed JSON.
    def delete(path)
      uri = build_uri(path)
      ctx = { method: "DELETE", path: path }
      resp = do_request(Net::HTTP::Delete.new(uri), uri, ctx, headers: @base_headers)
      handle(resp, ctx)
    end

    # GET returning raw bytes (binary String). Sets
    # Accept: application/octet-stream and drops Content-Type.
    def get_bytes(path)
      uri = build_uri(path)
      ctx = { method: "GET", path: path }
      headers = @base_headers.dup
      headers["Accept"] = "application/octet-stream"
      headers.delete("Content-Type")
      resp = do_request(Net::HTTP::Get.new(uri), uri, ctx, headers: headers)

      unless success?(resp)
        body = parse_json_body(resp)
        Invoance.throw_for_status(resp.code.to_i, body,
                                  request_context: ctx,
                                  retry_after_seconds: parse_retry_after(resp["retry-after"]))
      end

      body = resp.body || ""
      body.dup.force_encoding(Encoding::BINARY)
    end

    # GET returning the decoded JSON value untyped (used by attestations raw).
    def get_raw(path)
      get(path)
    end

    private

    def build_uri(path, params = nil)
      base = "#{@config.base_url}/#{@config.api_version}#{path}"
      uri = URI.parse(base)
      if params
        pairs = params.reject { |_, v| v.nil? }.map { |k, v| [k.to_s, v.to_s] }
        uri.query = URI.encode_www_form(pairs) unless pairs.empty?
      end
      uri
    end

    def do_request(req, uri, ctx, headers:)
      headers.each { |k, v| req[k] = v }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @config.timeout
      http.read_timeout = @config.timeout
      http.write_timeout = @config.timeout if http.respond_to?(:write_timeout=)

      begin
        http.request(req)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error => e
        raise TimeoutError.new(
          "Request timed out after #{@config.timeout}s on #{ctx[:method]} #{ctx[:path]}",
          request_context: ctx
        )
      rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
        raise NetworkError.new(
          "Network failure on #{ctx[:method]} #{ctx[:path]}: #{e.message}",
          request_context: ctx
        )
      end
    end

    def handle(resp, ctx)
      body = parse_json_body(resp)
      Invoance.throw_for_status(resp.code.to_i, body,
                                request_context: ctx,
                                retry_after_seconds: parse_retry_after(resp["retry-after"]))
      body
    end

    def parse_json_body(resp)
      raw = resp.body
      return nil if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def success?(resp)
      code = resp.code.to_i
      code >= 200 && code < 300
    end

    # Parse the Retry-After header: numeric seconds, or an HTTP-date
    # converted to a delta from now (floored at 0). Returns nil if absent
    # or unparseable.
    def parse_retry_after(value)
      return nil if value.nil? || value.to_s.strip.empty?

      s = value.to_s.strip
      if s.match?(/\A\d+(\.\d+)?\z/)
        seconds = s.to_f
        return seconds if seconds >= 0
      end

      begin
        ts = Time.httpdate(s)
        delta = ts.to_f - Time.now.to_f
        return delta.negative? ? 0.0 : delta
      rescue ArgumentError
        nil
      end
    end
  end
end
