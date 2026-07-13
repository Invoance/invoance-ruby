# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-07-14

### Changed

- `Client#validate` now probes the scope-free introspection endpoint
  `GET /v1/me` instead of `GET /v1/events?limit=1`. Keys restricted to
  `audit:*` scopes now validate correctly (the old events probe could 403
  on a missing events scope and report a misleading reason). The return
  shape (`"valid"` / `"reason"` / `"base_url"`) and the 401 / 403 / 429 /
  network classifications are unchanged; only the 403 `reason` text changed —
  it now describes an IP-access-rule block instead of a missing events
  permission, since `/v1/me` requires no scope.

### Added

- `Client#me` — API-key introspection via `GET /v1/me`. Returns the raw
  decoded response (organization, tenant, api_key with scopes, limits) as a
  string-keyed `Hash`; raises like any other resource call.
- Audit org lifecycle methods on `audit.orgs`:
  - `update(organization_id, name:)` — rename an org via
    `PATCH /audit/orgs/:org_id`; pass `name: nil` to clear the name.
  - `archive(organization_id)` / `unarchive(organization_id)` — idempotent
    `POST /audit/orgs/:org_id/archive` and `.../unarchive`. Archiving freezes
    new activity while history stays verifiable.
  - `delete(organization_id)` — hard delete via `DELETE /audit/orgs/:org_id`;
    raises `ConflictError` (`org_not_deletable`) when signed history would be
    destroyed.
- `audit.orgs.list(include_archived: true)` — include archived orgs in
  listings (excluded by default). Org responses now carry `archived_at`
  (RFC 3339 string or `nil`).
- `PATCH` support in the HTTP transport.

## [0.1.0] - 2026-07-06

### Added

- Initial release of the official Ruby SDK for the Invoance compliance API.
- `Invoance::Client` with resource accessors: `events`, `documents`,
  `attestations`, `traces`, and `audit` (sub-resources `audit.events`,
  `audit.orgs`, `audit.streams`, `audit.portal_sessions`, `audit.exports`).
- Synchronous HTTP transport built on Ruby stdlib (`net/http`) with zero runtime
  gem dependencies.
- Full error hierarchy under `Invoance::Error` (`AuthenticationError`,
  `ForbiddenError`, `NotFoundError`, `ValidationError`, `ConflictError`,
  `QuotaExceededError`, `ServerError`, `NetworkError`, `TimeoutError`) with
  status-code mapping and `Retry-After` parsing.
- Client-side input validation for SHA-256 hex digests.
- Offline audit-log verification: `invoance.audit/1` canonicalization
  (`Invoance::AuditCanonical`) and Ed25519 signature verification
  (`Invoance::AuditVerify`) using stdlib OpenSSL.
- `attestations.verify_signature` and `attestations.verify_payload` for
  client-side AI-attestation verification.
- `Invoance::Resources.content_idempotency_key` for content-stable idempotency keys.
- `Client#validate` for a non-raising API-key/connectivity probe.
