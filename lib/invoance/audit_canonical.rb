# frozen_string_literal: true

require "json"
require "digest"

module Invoance
  # `invoance.audit/1` canonical serializer (client-side).
  #
  # Reproduces the server's frozen canonicalization so an event's signature
  # can be checked offline. Canonical bytes = build the signed object
  # (signed fields present + non-nil, timestamps normalized, forced
  # schema_id), strip nil members recursively, sort every object's keys
  # deeply (alphabetical), emit compact UTF-8.
  #
  # NOTE: Ruby's JSON.generate produces compact output, does NOT escape
  # forward slashes, and emits UTF-8 literally — matching Node's
  # JSON.stringify.
  module AuditCanonical
    AUDIT_SCHEMA_ID = "invoance.audit/1"

    SIGNED_FIELDS = %w[
      org_id event_id seq ingested_at action occurred_at actor targets context metadata
    ].freeze

    REQUIRED_FIELDS = %w[
      org_id event_id seq ingested_at action occurred_at actor targets
    ].freeze

    RFC3339 = /\A(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|z|[+-]\d{2}:\d{2})\z/.freeze

    module_function

    # RFC3339 -> the one canonical form: UTC, exactly 3 fractional digits, `Z`.
    # Fractional seconds are TRUNCATED to millis (not rounded).
    #
    # @param value [String]
    # @return [String]
    def normalize_ts(value)
      raise ArgumentError, "timestamp must be a string" unless value.is_a?(String)

      m = RFC3339.match(value.strip)
      raise ArgumentError, "invalid RFC3339 timestamp: #{value}" unless m

      yr, mo, dy, hh, mi, ss, frac, off = m.captures
      millis = ((frac || "") + "000")[0, 3].to_i

      # Build UTC epoch (in milliseconds) manually — no rounding.
      base = Time.utc(yr.to_i, mo.to_i, dy.to_i, hh.to_i, mi.to_i, ss.to_i)
      epoch_ms = (base.to_i * 1000) + millis

      unless off == "Z" || off == "z"
        sign = off[0] == "+" ? 1 : -1
        oh = off[1, 2].to_i
        om = off[4, 2].to_i
        epoch_ms -= sign * (oh * 3600 + om * 60) * 1000
      end

      secs, ms = epoch_ms.divmod(1000)
      d = Time.at(secs).utc
      format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
             d.year, d.month, d.day, d.hour, d.min, d.sec, ms)
    end

    # @api private
    def strip_nils(v)
      case v
      when Array
        v.map { |x| strip_nils(x) }
      when Hash
        out = {}
        v.each do |k, val|
          next if val.nil?

          out[k] = strip_nils(val)
        end
        out
      else
        v
      end
    end

    # @api private
    def sort_deep(v)
      case v
      when Array
        v.map { |x| sort_deep(x) }
      when Hash
        v.keys.map(&:to_s).sort.each_with_object({}) do |k, out|
          # Keys may be symbols or strings on the input; normalize lookup.
          orig = v.key?(k) ? k : k.to_sym
          out[k] = sort_deep(v[orig])
        end
      else
        v
      end
    end

    # @api private
    def build_signed_object(event)
      unless event.is_a?(Hash)
        raise ArgumentError, "event must be a JSON object"
      end

      e = stringify_keys(event)
      REQUIRED_FIELDS.each do |f|
        if e[f].nil?
          raise ArgumentError, "missing required field: #{f}"
        end
      end

      out = {}
      SIGNED_FIELDS.each do |f|
        val = e[f]
        next if val.nil?

        out[f] = (f == "occurred_at" || f == "ingested_at") ? normalize_ts(val) : val
      end
      out["schema_id"] = AUDIT_SCHEMA_ID
      out
    end

    # The canonical signed bytes for an audit event (binary String).
    #
    # @param event [Hash]
    # @return [String] compact UTF-8 JSON
    def canonical_audit_bytes(event)
      signed = sort_deep(strip_nils(build_signed_object(event)))
      JSON.generate(signed)
    end

    # payload_hash = SHA-256(canonical bytes), lowercase hex.
    #
    # @param canonical [String]
    # @return [String]
    def payload_hash_hex(canonical)
      Digest::SHA256.hexdigest(canonical)
    end

    # @api private
    def stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
    end
  end
end
