# frozen_string_literal: true

# Invoance — Official Ruby SDK for the Invoance compliance API.
#
#   require "invoance"
#
#   client = Invoance::Client.new(api_key: "inv_live_abc123")
#   event = client.events.ingest(event_type: "user.login", payload: { user_id: "u_42" })
#
# Audit-log offline verification helpers live in {Invoance::AuditVerify} and
# {Invoance::AuditCanonical}; the content-idempotency-key helper is
# {Invoance::Resources.content_idempotency_key}.
module Invoance
end

require_relative "invoance/version"
require_relative "invoance/errors"
require_relative "invoance/config"
require_relative "invoance/validate"
require_relative "invoance/http"
require_relative "invoance/audit_canonical"
require_relative "invoance/audit_verify"
require_relative "invoance/resources/events"
require_relative "invoance/resources/documents"
require_relative "invoance/resources/attestations"
require_relative "invoance/resources/traces"
require_relative "invoance/resources/audit"
require_relative "invoance/client"
