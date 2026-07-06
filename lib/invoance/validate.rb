# frozen_string_literal: true

require_relative "errors"

module Invoance
  # Shared client-side input validators.
  # @api private
  module Validate
    HEX_SHA256 = /\A[0-9a-f]{64}\z/.freeze

    # Validate that a value is a 64-char lowercase hex SHA-256 digest.
    # Raises {Invoance::ValidationError} with a helpful message otherwise.
    #
    # @param field_name [String]
    # @param value [Object]
    # @return [void]
    def self.assert_sha256_hex(field_name, value)
      unless value.is_a?(String)
        raise ValidationError,
              "#{field_name} must be a string containing a 64-char hex SHA-256 digest " \
              "(got #{value.class})"
      end
      if value.length != 64
        raise ValidationError, "#{field_name} must be 64 hex chars (got #{value.length} chars)"
      end
      unless HEX_SHA256.match?(value)
        raise ValidationError,
              "#{field_name} must be lowercase hex [0-9a-f]; \"#{value[0, 16]}…\" is not"
      end
    end
  end
end
