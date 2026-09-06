# 06 — Security Model and Privacy / Data Protection

All Proposed. Tenant isolation controls are summarised in `03-multi-tenancy-and-roles.md`; this document is the complete security model.

## Authentication

- Email + password (argon2id hashing, minimum 12 characters, breached-password check via k-anonymity range API), passwordless magic link, and OAuth (Google, Microsoft) — all through the auth library's adapter storing data in our Postgres.
- Email verification required before joining or creating an organisation.
- Optional TOTP two-factor for any user; **enforceable per organisation** ("require 2FA for all members") by owner/admin — should-have for MVP, must-have before launch.
- Sign-in throttling: 5 failures per email per 15 min and 20 per IP per 15 min, then exponential backoff; generic error messages; audited.
- Password reset tokens: single-use, 30-minute expiry, hashed at rest; invalidates existing sessions on success.
- Invitations: single-use hashed tokens, 7-day expiry, bound to the invited email.

## Session management

- Server-side sessions stored in Postgres, referenced by an opaque, httpOnly, `Secure`, `SameSite=Lax` cookie. No JWT-as-session (revocation must be immediate).
- Idle timeout 14 days rolling, absolute lifetime 90 days; configurable per organisation later.
- Session record stores user agent, IP hash, created/last-seen; users can view and revoke sessions; role changes and removals revoke that user's sessions for the organisation on the next request (membership is re-read per request).
- CSRF: Server Actions carry origin checks; Route Handlers for state-changing requests require a same-site cookie plus a custom header or the auth library's CSRF token.

## Authorisation

- Two questions on every request: **which tenant** (membership lookup, cached per request only) and **which action** (`can(ctx, action)` from the static role map in `permissions.ts`).
- Deny by default. Services, not handlers or UI, are the authoritative check.
- Ownership checks ("edit own records") compare `record.owner_id === ctx.userId` inside the service after loading the record within the tenant scope.

## Tenant isolation (database access)

- Two Postgres roles: `crm_migrator` (DDL, used only by migrations, not by the app) and `crm_app` (DML only, **no BYPASSRLS**, not table owner). The app connects only as `crm_app`.
- Every tenant table: `ENABLE` + `FORCE ROW LEVEL SECURITY` with the `tenant_isolation` policy. A migration-time check (and a CI test) fails if any table with `organisation_id` lacks a forced policy.
- `app.current_org` is set with `SET LOCAL` inside a transaction by `withTenant`; outside a transaction the setting is empty and the policy evaluates to false, so a query without tenant context returns nothing.
- Connection pooling: transaction-mode pooling is compatible because `SET LOCAL` is transaction-scoped. Never use `SET` (session scope) for tenant context.
- Composite foreign keys `(organisation_id, id)` on cross-entity links so a cross-tenant reference is rejected by the database even if RLS were disabled.
- Platform-admin access uses a separate role `crm_platform` with a `platform_bypass` policy gated on `current_setting('app.platform_admin_user')`, only reachable through the `platform` module which requires a `platform_admins` row, a stated reason, a short-lived elevated session (30 min, re-auth with 2FA), and writes a `platform_access` audit row visible to the affected organisation's owner.

## API access (public API is post-MVP; principles fixed now)

- API keys: per organisation, created by owner/admin, shown once, stored as SHA-256 hash with a prefix for identification, scoped (`contacts:read`, `contacts:write`, …), optional expiry, revocable, last-used tracking. Keys act as `actor_type = api_key` in audit.
- Keys are tenant-bound; the tenant is derived from the key, never from the request.
- Same services and permission checks as the UI; API keys map to a role (`member`-level by default, `manager` optional) so no new authorisation path is created.

## Rate limiting

- Per user and per organisation on Server Actions (e.g. 600 mutations / 10 min / user), stricter on expensive operations (export, import, bulk, search: 60 / min).
- Per IP on unauthenticated endpoints (sign-in, sign-up, password reset, invitation acceptance).
- Implemented with a Postgres-backed token bucket in MVP (no Redis); swap to an edge/Redis limiter later behind the same interface.

## Input validation

- All input parsed by Zod at the boundary (Server Actions, Route Handlers, job payloads, CSV import rows). Unknown keys stripped. Length limits on every string. `organisationId`, `ownerId` acceptance validated against membership.
- Custom field values validated against the generated per-organisation schema.
- Output encoding by React by default; notes/body rendered as sanitised Markdown (allowlist) — never raw HTML.
- File uploads (CSV import): size limit 10 MB, MIME sniffing, parsed server-side with a streaming parser, formula-injection protection on export (prefix `'` for cells beginning with `= + - @`).
- SQL only via the query builder with parameters; raw SQL fragments reviewed and tested.

## Audit logging

Covered in `03`. Additional security events: sign-in success/failure, 2FA enable/disable, password change, session revoke, API key create/revoke, export requested/downloaded, platform-admin access, role change, member removal, organisation deletion scheduled/cancelled.

## Sensitive data handling

- PII classification: names, emails, phones, addresses, notes, custom fields are personal data. They are never written to application logs or error reports (structured logging with an allowlist of fields; Sentry `beforeSend` scrubber).
- Encryption in transit (TLS everywhere, HSTS). Encryption at rest provided by the managed database and object storage; application-level encryption (per-tenant keys) for future integration credentials (OAuth refresh tokens) using a KMS-backed envelope scheme — required before GCRM-9.
- Secrets in environment variables managed by the hosting provider; no secrets in the repository; `.env.example` lists names only.
- Backups contain PII; access restricted to the platform operator; see retention.

## Deletion and export

See `03`. Security-relevant additions: export downloads use signed URLs (15-minute expiry), are audited, are limited by rate limit, and full-organisation exports require re-authentication.

## Backups and recovery

- Managed Postgres: daily snapshots + point-in-time recovery with 7-day window (provider-dependent; **open decision**). Retention for snapshots 30 days.
- Quarterly restore drill into a staging environment, documented.
- Recovery objectives (proposed): RPO ≤ 5 minutes (PITR), RTO ≤ 4 hours.
- Tenant-level restore ("undo a bulk delete") is served by soft-delete + Recently Deleted for 30 days, not by database restores.

## Administrator (platform) access

- Platform admins are a separate list, not organisation members. They cannot see tenant data through the normal UI at all.
- "Impersonation" is not offered in MVP. A read-only support view of an organisation's metadata (plan, member count, health) is available without PII; access to record data requires the break-glass flow above, which notifies the organisation owner by email.

## Transport and application hardening

- Security headers: CSP (nonce-based scripts), `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors 'none'`.
- Dependencies: lockfile committed, Dependabot/Renovate, `pnpm audit` in CI, no post-install scripts by default (pnpm 10+ blocks them).
- Error responses never include stack traces or SQL in production.

## Automated tests that must prove tenant isolation

These live in `tests/isolation/` and block merge (details in `10-testing-strategy.md`):

1. **Policy coverage:** every table with `organisation_id` has RLS enabled and forced, and the `crm_app` role lacks BYPASSRLS. Fails the build otherwise.
2. **Repository sweep:** for every repository method, executed with a context for org A after seeding identical data in org B, asserts results contain only org A ids (a generated matrix test using module registration).
3. **IDOR by id:** every `getById`/`update`/`delete` service method called with org A's context and org B's id returns not-found, never the record and never "forbidden" (to avoid existence leaks).
4. **Cross-tenant references:** creating a contact in org A with `company_id` from org B is rejected; same for stage/pipeline/lead status/owner.
5. **No-context queries:** a query run outside `withTenant` returns zero rows on every tenant table.
6. **Search & dashboard:** global search and dashboard aggregates for org A never include org B rows.
7. **Jobs & exports:** an export job for org A produces a file containing zero org B identifiers (grep the artefact).
8. **Membership revocation:** after removing a user from org A, their next request to any org A route is denied and their session for that org is invalid.
9. **HTTP-level E2E:** Playwright signs in as org A user and requests org B URLs and ids directly; expects 404 for records and a "no access" page for the organisation.

## Privacy and data protection (GDPR and similar)

The platform operator will be a **processor** for tenant CRM data and a **controller** for account/billing data. Nothing here is a claim of compliance; each row lists what the product provides and what remains a legal/product decision.

| Requirement | Product provision (MVP unless noted) | Requires decision |
|---|---|---|
| Lawful basis / consent for contact data | Tenants are controllers; `do_not_contact` flag and `consent` custom field pattern; future per-channel consent fields (email/SMS marketing) before GCRM-9 | Consent model detail |
| Right of access / portability | Per-contact JSON export; full-organisation export | Format expectations |
| Right to erasure | Contact hard delete + audit anonymisation; organisation deletion with 14-day grace | Whether tenants may disable Recently Deleted |
| Rectification | Standard editing; audit trail | — |
| Retention | Audit 12 months default; exports 7 days; soft-deleted 30 days; backups 30 days; no automatic retention on live records (should-have: per-tenant "archive contacts inactive for N months") | Retention defaults and plan limits |
| Data residency | Region chosen at deployment (EU/UK proposed); single region in MVP | Region; whether to offer choice per tenant |
| Sub-processors | Hosting, database, email, error reporting, (later) AI and email providers — must be listed publicly | Provider selection |
| DPA with tenants | Needed as part of terms | Legal drafting |
| Breach notification | Audit and logging support investigation; process needed | Incident response runbook |
| Privacy settings | Organisation-level: members' export permission, 2FA enforcement, data retention (should-have) | — |
| DPIA | Recommended before launching AI features (GCRM-12) and email sync (GCRM-9) | Legal |
| Cookies | Only strictly-necessary (session) cookies in the app; marketing site separate | Analytics choice |
| Children's data | Not targeted; no special handling | Terms wording |
| International transfers | Depends on providers (e.g. US-based error reporting) | SCCs / provider choice |
| Auditability | Append-only audit log; access logs; platform-admin access notifications | — |

**Open privacy decisions** are consolidated in `11-risks-and-open-decisions.md`.
