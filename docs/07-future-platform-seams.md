# 07 — Future Platform Seams: Communications, Automation, AI, Billing, Public API

None of this is built in MVP. The purpose is to fix the integration points so later phases add modules rather than redesign the core.

## 16. Communications (GCRM-9)

**Where it plugs in:** every inbound or outbound communication becomes an `activities` row via the activities service, exactly like a manual log, with `source = integration:<provider>` and `external_id` / `external_thread_id` for idempotency and threading. The timeline needs no changes to show synced email.

```text
Provider (Gmail / Outlook / SMS gateway / web form)
   │  webhook or polling job (per-organisation integration row)
   ▼
integrations module: provider adapter → normalised Message { from, to, subject, body, occurredAt, direction, externalId, threadId }
   │
   ▼  match participants → contacts by email/phone (create lead if unknown & setting enabled)
activities service.create(ctx, …)  → timeline, events, audit
```

**Tables reserved:** `integrations (organisation_id, provider, status, encrypted_credentials, settings, connected_by, last_sync_at)`, `integration_identities (integration_id, user_id, external_account)` for per-user mailbox connections, `inbound_forms (organisation_id, name, token, field_mapping, target: lead|contact)`.

**Design decisions to hold now**
- Per-user mailbox connection (each user connects their own Gmail/Outlook) rather than one org mailbox; privacy filter so only threads involving known CRM contacts are synced, with a per-user "exclude private" toggle.
- Outbound email from the CRM sends via the user's connected mailbox (not a shared sending domain) to preserve deliverability and reply threading; the sent message is logged as an activity.
- Web enquiry forms / contact forms: a tokenised endpoint `POST /api/v1/forms/{token}` that creates a lead with `source = Website`; spam control via honeypot + rate limit + optional Turnstile.
- SMS: provider adapter (Twilio-like); consent field required before enabling (privacy).
- Credentials encrypted with per-tenant envelope keys (security doc) — prerequisite.

## 17. Automation (GCRM-10)

**Model:** *Trigger → optional conditions → ordered actions*, evaluated by a worker consuming `outbox_events` plus a scheduled evaluator for time-based triggers.

```text
Trigger: lead.created
Conditions: source = "Website" AND owner is empty
Actions:
  1. assign_owner (round-robin among [users])
  2. create_task (title "Follow up {lead.name}", due +1 business day, assignee = owner)
  3. notify (owner, in-app + email)
```

```text
Trigger: schedule (daily)
Conditions: opportunity.status = open AND stage_entered_at < now - 14d AND no open task
Actions:
  1. create_task ("Check in on {opportunity.name}", assignee = owner)
```

**Tables reserved:** `automation_rules (organisation_id, name, trigger_type, trigger_config, conditions jsonb, actions jsonb, enabled, created_by)`, `automation_runs (rule_id, event_id, status, started_at, finished_at, error, actions_log jsonb)`.

**Architectural requirements satisfied in MVP**
- Domain events with stable names and payloads (`events` module), written to the outbox in the same transaction — the trigger source.
- All mutations go through services that accept a `TenantContext` with `actor_type = system` — actions reuse them, so automation cannot bypass validation, audit or events.
- Loop protection: events created by an automation carry `causation_id`/`depth`; rules do not fire on events with depth ≥ 3.
- Stalled thresholds (`rotting_after_days`) and `last_activity_at` denormalised now so time-based conditions are cheap.
- Plan entitlements (`entitlements` module) gate rule counts and run volume.

No visual builder: a form-based rule editor with a fixed catalogue of triggers, condition fields, and actions.

## 18. AI (GCRM-12)

**Integration points**

| Capability | Input | Where it appears | Mechanism |
|---|---|---|---|
| Summarise customer history | activities for a contact/company (last N) | "Summary" card on record page, cached with `summary_generated_at` and invalidated on new activity | background job → `ai_summaries (entity_type, entity_id, summary, model, generated_at)` |
| Summarise / analyse opportunity | opportunity + timeline + tasks | opportunity page | as above |
| Leads needing attention, stalled opportunities | structured query results (not the model) → model explains/prioritises | dashboard panel | scheduled job |
| Recommend follow-ups | timeline + tasks | record page, tasks page | on-demand action, result is a *suggested* task the user confirms |
| Draft emails | contact, recent activities, user prompt | email composer (GCRM-9) | on-demand, streamed |
| Natural-language questions ("which deals close this month?") | tool-calling over the **same services** with the user's `TenantContext` | ⌘K / assistant panel | model calls typed tools; tools enforce tenant + permission; results rendered as normal lists |

**Rules fixed now**
- AI never gets a database connection. It gets tools that wrap existing services with the caller's `TenantContext`, so tenant isolation and permissions hold automatically.
- AI writes are proposals (draft task, draft email, suggested field values) that a human confirms, except summaries which are clearly labelled as generated and stored separately from user data.
- Per-organisation AI toggle (default off until enabled by owner), sub-processor disclosure, and no training on tenant data — contractual requirement for the provider.
- Usage metering table `ai_usage (organisation_id, user_id, feature, input_tokens, output_tokens, cost_minor, created_at)` feeds billing entitlements.
- Provider abstraction (`AiProvider` interface); Anthropic Claude proposed as first provider (**open decision**).

## 19. Billing and SaaS model (GCRM-11)

**Plans (proposed, to be validated commercially)**

| | Free | Starter | Professional | Business |
|---|---|---|---|---|
| Users | 2 | 5 | 20 | unlimited (fair use) |
| Contacts | 500 | 5,000 | 50,000 | 250,000 |
| Pipelines | 1 | 1 | 5 | unlimited |
| Custom fields per entity | 5 | 15 | 50 | 100 |
| Automation rules / runs per month | 0 | 3 / 1,000 | 20 / 20,000 | 100 / 200,000 |
| Email sync | — | ✔ | ✔ | ✔ |
| AI | — | — | metered | included allowance + metered |
| Audit retention | 90 days | 12 months | 24 months | 7 years |
| API access / webhooks | — | — | ✔ | ✔ |
| 2FA enforcement, SSO | — | — | 2FA | 2FA + SSO |

**Architecture**
- `entitlements` module in MVP exposes `limits(orgId)` and `assertWithinLimit(ctx, 'contacts')`; MVP reads limits from the `plan` enum on `organisations` (all orgs `free` with generous dev limits or an env override). Billing later replaces the source of truth without changing call sites.
- `usage_counters (organisation_id, metric, period, value)` maintained by services (contacts count, users count, automation runs, AI tokens).
- Provider: Stripe (Checkout + Customer Portal + webhooks) proposed. Tables reserved: `subscriptions (organisation_id, provider, provider_customer_id, provider_subscription_id, plan, status[trialing|active|past_due|cancelled|paused], current_period_end, cancel_at)`, `billing_events` (raw webhook log, idempotent by provider event id).
- Subscription state drives `organisations.plan` via webhook; grace period on `past_due` (read-only after 14 days, never deletion without notice).
- Only the owner manages billing; billing pages never expose card data (Stripe-hosted).
- Downgrade rules: exceeding limits after downgrade blocks *creation* of the limited resource, never deletes data.

## 22. Public API and webhooks (GCRM-9 onward; reserved namespace now)

**Shape:** REST, JSON, `/api/v1/…`, versioned in the path; breaking changes only via `/v2`. OpenAPI 3.1 document generated from Zod schemas (single source of truth with the UI).

**Authentication:** `Authorization: Bearer <api_key>` (see security doc). Later: OAuth 2.0 client credentials for marketplace integrations. Every key is bound to one organisation.

**Tenant scoping:** derived from the key; URLs never contain organisation ids. Same services and `TenantContext` as the UI.

**Permissions:** scopes on the key, intersected with the mapped role.

**Rate limits:** per key, e.g. 600 requests/min burst 100, headers `RateLimit-*`; 429 with `Retry-After`. Plan-dependent.

**Resources:** contacts, companies, leads, opportunities, pipelines (read), stages (read), activities, tasks, tags, custom-field definitions (read), users (read). Cursor pagination, `updated_since` filtering, sparse fieldsets, idempotency keys on POST.

**Webhooks:** `webhooks (organisation_id, url, secret_hash, events[], enabled)`, `webhook_deliveries (webhook_id, event_id, status, attempts, response_code, next_retry_at)`. Delivered from the outbox with HMAC-SHA256 signature header, timestamp, retries with backoff (up to 24 h), automatic disable after sustained failure, replay from the UI. Payloads contain ids and changed fields, never other tenants' data.

**Consumers anticipated:** websites (forms → leads), SaaS products (customer sync), marketing platforms (tags/segments), accounting (customer records, won opportunities), communication tools, mobile apps (same API + session auth).

**Not built in MVP** because nothing in the MVP architecture requires it; the `/api/v1` namespace, the key model and the outbox are the only reservations.
