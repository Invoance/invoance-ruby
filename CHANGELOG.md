# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
