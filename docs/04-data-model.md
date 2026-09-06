# 04 — CRM Data Model

All tables use UUIDv7 primary keys named `id`. Every tenant-scoped table carries `organisation_id` (NOT NULL, FK → organisations, indexed) and is covered by RLS. Standard columns unless stated otherwise:

| Column | Type | Notes |
|---|---|---|
| `created_at` | timestamptz | NOT NULL default now() |
| `updated_at` | timestamptz | NOT NULL, maintained by the application |
| `created_by` | uuid → users | nullable for system-created rows |
| `updated_by` | uuid → users | nullable |
| `deleted_at`, `deleted_by` | timestamptz, uuid | soft delete; NULL = live |
| `archived_at` | timestamptz | on contacts, companies, opportunities, pipelines; hidden from default lists but not "deleted" |
| `custom_fields` | jsonb | NOT NULL default `'{}'`, on contacts, companies, leads, opportunities; GIN index |

Legend: **R** required, **O** optional.

## Entity relationship overview

```text
organisations 1──* memberships *──1 users
organisations 1──* invitations

companies 1──* contacts                 (contact.company_id, O)
companies 1──* opportunities            (O)
contacts  1──* opportunities            (O; plus opportunity_contacts for extra participants)

leads ──converts to──> contacts / companies / opportunities  (lead.converted_*_id)
leads *──1 lead_statuses (per organisation)

pipelines 1──* pipeline_stages
opportunities *──1 pipelines, *──1 pipeline_stages

activities *──? contacts | companies | leads | opportunities  (nullable FKs; at least one)
tasks      *──? contacts | companies | leads | opportunities  (nullable FKs; none required)

tags 1──* taggings *──(contact|company|lead|opportunity)
custom_field_definitions (per organisation, per entity_type) describe keys inside custom_fields jsonb

users 1──* (owner_id on contacts, companies, leads, opportunities, tasks)
audit_log, outbox_events, exports, saved_views (future), api_keys (future), webhooks (future)
```

## Platform-level tables (not tenant-scoped, no `organisation_id`)

### users
| Column | R/O | Notes |
|---|---|---|
| id | R | |
| email | R | citext, unique, verified via `email_verified_at` |
| name | R | display name |
| avatar_url | O | |
| password_hash | O | null when only OAuth/magic link |
| locale, timezone | O | defaults `en-GB`, `Europe/London` (**open decision**) |
| last_active_at | O | |
| disabled_at | O | platform-level suspension |
| created_at, updated_at | R | |

Auth-library tables (`sessions`, `accounts`, `verification_tokens`) are owned by the auth adapter and treated as platform-level.

### platform_admins
`user_id` (unique), `granted_by`, `granted_at`, `revoked_at`. Grants super-admin capability; separate from any organisation role.

## Tenancy tables

### organisations
| Column | R/O | Notes |
|---|---|---|
| id | R | |
| name | R | |
| slug | R | unique, lowercase, URL-safe, immutable after creation (rename = new slug with redirect, post-MVP) |
| default_currency | R | ISO 4217, default from **open decision** (GBP proposed) |
| timezone | R | |
| settings | R | jsonb: `{ membersCanEditAll: false, membersCanExport: false, fiscalYearStart: 1, dateFormat: … }` |
| plan | R | enum `free|starter|professional|business`, default `free` (seam for billing) |
| plan_limits_override | O | jsonb, platform-admin only |
| status | R | `active|deletion_scheduled|deleted|suspended` |
| deletion_scheduled_for | O | |
| created_at, updated_at | R | |

### memberships
`id`, `organisation_id`, `user_id`, `role` (`owner|admin|manager|member`), `status` (`active|suspended`), `joined_at`, `invited_by`. Unique `(organisation_id, user_id)`. Partial unique index: exactly one `owner` per organisation.

### invitations
`id`, `organisation_id`, `email` (citext), `role`, `token_hash`, `invited_by`, `expires_at` (7 days), `accepted_at`, `revoked_at`. Unique `(organisation_id, email)` where pending.

## CRM core tables

### companies
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| name | R | |
| website | O | normalised (lowercase host) |
| domain | O | derived from website/email, used for duplicate detection; index `(organisation_id, domain)` |
| phone | O | E.164 normalised + `phone_raw` |
| email | O | generic company email |
| address_line1, address_line2, city, region, postal_code, country | O | country ISO 3166-1 alpha-2 |
| industry | O | free text in MVP; select custom field pattern later |
| size | O | enum bucket `1-10|11-50|51-200|201-1000|1000+` |
| description | O | text |
| status | R | `prospect|customer|former|other`, default `prospect` |
| source | O | text (from configurable sources list) |
| owner_id | O | → users; must be a member of the organisation (service-enforced) |
| custom_fields | R | jsonb |
| archived_at, deleted_at… | | standard |

Indexes: `(organisation_id, name)`, `(organisation_id, owner_id)`, `(organisation_id, status)`, `(organisation_id, updated_at desc)`, GIN on `custom_fields`, GIN on `search_vector` (generated tsvector over name, domain, city). Deletion: soft; contacts keep `company_id` but the UI shows "(deleted company)"; hard delete sets `contacts.company_id = NULL`.

### contacts
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| first_name | O* | *at least one of first_name, last_name, email must be present (CHECK) |
| last_name | O* | |
| email | O | citext, normalised; **not unique** (duplicates allowed but flagged) |
| phone | O | E.164 + raw |
| mobile | O | E.164 + raw |
| job_title | O | |
| company_id | O | → companies (same tenant; composite FK `(organisation_id, id)` on companies) |
| website | O | |
| address_line1 … country | O | as companies |
| status | R | `lead|prospect|customer|former|other`, default `prospect`. (`lead` here means "a contact who is still only a lead", distinct from the Lead entity; used after lead conversion without opportunity) |
| source | O | |
| owner_id | O | → users |
| notes | O | text; a free "about" field. Dated notes are Activities |
| do_not_contact | R | boolean default false (consent flag placeholder) |
| last_activity_at | O | denormalised, maintained by activities service; drives "going quiet" |
| custom_fields | R | jsonb |
| archived_at, deleted_at… | | standard |

Indexes: `(organisation_id, email)`, `(organisation_id, last_name, first_name)`, `(organisation_id, company_id)`, `(organisation_id, owner_id)`, `(organisation_id, status)`, `(organisation_id, last_activity_at)`, GIN `custom_fields`, GIN `search_vector` (names, email, phone digits, job title), trigram index on `(first_name || ' ' || last_name)` for fuzzy duplicate detection.

### lead_statuses (configurable lifecycle)
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| name | R | e.g. New, Contacted, Qualified, Interested |
| position | R | int; unique `(organisation_id, position)` (deferrable) |
| colour | R | token name, not hex, so themes work |
| kind | R | `open|converted|lost` — exactly one `converted` and at least one `lost` per organisation |
| is_default | R | exactly one default (`kind = open`) per organisation |
| archived_at | O | cannot archive a status while leads reference it |

Seeded on organisation creation: New (default), Contacted, Qualified, Interested, Converted (kind converted), Lost (kind lost).

### leads
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| first_name, last_name | O* | at least one of name fields, email, phone, or company_name (CHECK) |
| email, phone, mobile | O | normalised |
| company_name | O | free text until converted |
| job_title, website | O | |
| status_id | R | → lead_statuses |
| source | O | |
| owner_id | O | |
| qualification | O | jsonb `{ budget?, authority?, need?, timeline?, score? }` — light BANT-style, optional; plus `score` int 0–100 |
| description | O | the enquiry text |
| lost_reason | O | text, required by UI when moving to a `lost` status |
| converted_at | O | |
| converted_contact_id, converted_company_id, converted_opportunity_id | O | set on conversion; lead becomes read-only |
| last_activity_at | O | |
| custom_fields | R | |
| deleted_at… | | standard |

Indexes: `(organisation_id, status_id)`, `(organisation_id, owner_id)`, `(organisation_id, email)`, `(organisation_id, created_at desc)`, GIN search_vector.

### pipelines
`organisation_id`, `name` (R), `description`, `position`, `is_default` (exactly one per org), `currency_override` (O), `archived_at`. Unique `(organisation_id, name)`. MVP UI exposes one pipeline; the schema allows many.

### pipeline_stages
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | denormalised for RLS |
| pipeline_id | R | |
| name | R | |
| position | R | unique `(pipeline_id, position)` deferrable |
| probability | R | int 0–100; default by kind (won = 100, lost = 0) |
| kind | R | `open|won|lost`; at least one `won` and one `lost` per pipeline |
| colour | R | token |
| rotting_after_days | O | "stale" indicator threshold (seam for automation) |
| archived_at | O | cannot archive while opportunities are in the stage; must move them first |

Seeded default pipeline: Qualification 20% → Proposal 40% → Negotiation 70% → Won (won, 100%) → Lost (lost, 0%).

### opportunities
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| name | R | |
| pipeline_id | R | |
| stage_id | R | must belong to pipeline_id (service + composite FK) |
| contact_id | O | primary contact |
| company_id | O | |
| value_minor | O | bigint, minor units (pence/cents); never float |
| currency | R | ISO 4217; defaults to organisation default |
| probability | R | int; defaults from stage on stage change, user may override; `probability_overridden` boolean |
| expected_close_date | O | date |
| status | R | `open|won|lost` — derived from stage kind, denormalised for indexing |
| won_at, lost_at | O | |
| lost_reason | O | |
| source | O | |
| owner_id | O | |
| description | O | |
| stage_entered_at | R | for stage-age / stalled detection |
| last_activity_at | O | |
| lead_id | O | originating lead |
| custom_fields | R | |
| archived_at, deleted_at… | | standard |

Indexes: `(organisation_id, pipeline_id, stage_id)`, `(organisation_id, status, expected_close_date)`, `(organisation_id, owner_id)`, `(organisation_id, contact_id)`, `(organisation_id, company_id)`, `(organisation_id, stage_entered_at)`.

### opportunity_contacts
Join for additional participants: `organisation_id`, `opportunity_id`, `contact_id`, `role` (text, e.g. decision maker). Unique `(opportunity_id, contact_id)`.

### activities (unified timeline)
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| type | R | `note|call|email|meeting|message|status_change|stage_change|task_completed|system` |
| subject | O | short title (email subject, call summary) |
| body | O | text/markdown |
| occurred_at | R | when it happened (user-editable for back-dated entries); default now |
| direction | O | `inbound|outbound` for calls/emails/messages |
| duration_minutes | O | calls/meetings |
| contact_id, company_id, lead_id, opportunity_id | O | **at least one NOT NULL** (CHECK). Denormalise: when contact has a company, activity gets both so the company timeline is complete |
| task_id | O | for `task_completed` |
| actor_user_id | O | null for system/integration |
| source | R | `manual|system|integration:<provider>|api` |
| external_id, external_thread_id | O | for future email/SMS sync idempotency; unique `(organisation_id, source, external_id)` |
| metadata | O | jsonb (e.g. before/after for status_change) |
| pinned | R | boolean, notes can be pinned to top |
| deleted_at… | | soft delete; system activities cannot be deleted by users |

Indexes: `(organisation_id, contact_id, occurred_at desc)`, `(organisation_id, company_id, occurred_at desc)`, `(organisation_id, lead_id, occurred_at desc)`, `(organisation_id, opportunity_id, occurred_at desc)`, `(organisation_id, occurred_at desc)` for the global feed, `(organisation_id, actor_user_id, occurred_at desc)`.

### tasks
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| title | R | |
| description | O | |
| due_at | O | timestamptz; `due_date` date + optional time; store `all_day` boolean |
| priority | R | `low|normal|high|urgent`, default normal |
| status | R | `open|completed|cancelled` |
| completed_at, completed_by | O | |
| assignee_id | O | → users (member); defaults to creator |
| contact_id, company_id, lead_id, opportunity_id | O | none required (standalone tasks allowed) |
| reminder_at | O | seam for notifications |
| recurrence_rule | O | RFC 5545 RRULE text; **schema only in MVP**, no UI |
| recurrence_parent_id | O | |
| deleted_at… | | |

Overdue is derived: `status = open AND due_at < now()`. Indexes: `(organisation_id, assignee_id, status, due_at)`, `(organisation_id, status, due_at)`, and per-entity FKs.

### tags
`organisation_id`, `name` (R), `colour`, `entity_types` (text[] — which entities the tag may be applied to; empty = all). Unique `(organisation_id, lower(name))`.

### taggings
`organisation_id`, `tag_id`, `entity_type` (`contact|company|lead|opportunity`), `entity_id`. Unique `(tag_id, entity_type, entity_id)`. Index `(organisation_id, entity_type, entity_id)`. Polymorphic by design (no FK to entity); the entity services delete taggings on hard delete. Trade-off accepted for simplicity; revisit if integrity issues appear.

### custom_field_definitions
| Column | R/O | Notes |
|---|---|---|
| organisation_id | R | |
| entity_type | R | `contact|company|lead|opportunity` |
| key | R | machine key `^[a-z][a-z0-9_]{0,39}$`; unique `(organisation_id, entity_type, key)`; immutable |
| label | R | |
| type | R | `text|textarea|number|currency|date|boolean|select|multiselect|url|email|phone` |
| options | O | jsonb `[{ value, label, colour }]` for select types |
| required | R | boolean (enforced on create/edit in UI and service, not by DB) |
| position | R | |
| show_in_list | R | boolean |
| archived_at | O | archived fields keep their data but are hidden |

Values live in the entity's `custom_fields` jsonb as `{ key: value }`. Validation is performed by a Zod schema generated from definitions at request time. Limits per plan (seam for billing).

### sources (lightweight configurable list)
`organisation_id`, `name`, `position`, `archived_at`. Unique `(organisation_id, lower(name))`. Seeded: Website, Referral, Phone, Email, Social, Event, Advert, Other. Entities store `source` as text (the name) so deleting a source never orphans data.

## Supporting tables

### audit_log
See `03-multi-tenancy-and-roles.md`. Indexes `(organisation_id, created_at desc)`, `(organisation_id, entity_type, entity_id)`, `(organisation_id, actor_user_id)`.

### outbox_events
`id`, `organisation_id`, `event_type`, `entity_type`, `entity_id`, `payload` jsonb, `created_at`, `processed_at`, `attempts`, `last_error`. Index on `(processed_at) WHERE processed_at IS NULL`.

### exports
`id`, `organisation_id`, `requested_by`, `kind` (`entity_csv|organisation_full|data_subject`), `filters` jsonb, `status`, `file_key`, `expires_at`, `row_count`, `created_at`, `completed_at`.

### jobs (pg-boss owns its own schema)
Tenant id inside payload; not a domain table.

### Reserved for later phases (schema not created in MVP)
`api_keys`, `webhooks`, `webhook_deliveries`, `integrations`, `automation_rules`, `automation_runs`, `saved_views`, `subscriptions`, `usage_counters`, `ai_jobs`, `attachments`.

## Deletion and archival behaviour summary

| Entity | Soft delete | Archive | Hard delete effect |
|---|---|---|---|
| Company | yes | yes | contacts.company_id → NULL; opportunities.company_id → NULL; activities/company_id → NULL; taggings removed |
| Contact | yes | yes | opportunities.contact_id → NULL; opportunity_contacts rows removed; activities.contact_id → NULL (activity kept if another FK remains, else deleted); tasks.contact_id → NULL; taggings removed; audit payloads anonymised on erasure requests |
| Lead | yes | no | converted_* links on contact side are informational; activities/tasks FKs → NULL |
| Opportunity | yes | yes (won/lost auto-archive after N days, configurable) | activities/tasks FK → NULL; opportunity_contacts removed |
| Activity | yes (manual types only) | no | row removed |
| Task | yes | no | row removed |
| Pipeline / stage | no | yes, only when empty | forbidden while referenced |
| Lead status | no | yes, only when unreferenced | forbidden while referenced |
| Tag | hard delete | no | taggings removed |
| Custom field definition | no | yes | values remain in jsonb, hidden |

## Uniqueness and integrity constraints (summary)

- `users.email` unique (citext).
- `organisations.slug` unique.
- `memberships (organisation_id, user_id)` unique; one owner per organisation (partial unique index on role = 'owner').
- `pipelines`: one `is_default` per organisation (partial unique index).
- `lead_statuses`: one default per organisation; one `converted` kind per organisation.
- `custom_field_definitions (organisation_id, entity_type, key)` unique.
- `tags (organisation_id, lower(name))` unique.
- `activities (organisation_id, source, external_id)` unique where external_id not null.
- CHECK constraints: activity has at least one parent; contact has at least one identifying field; lead has at least one identifying field; `value_minor >= 0`; `probability BETWEEN 0 AND 100`.
- Composite foreign keys `(organisation_id, <fk>)` referencing `(organisation_id, id)` on companies, contacts, pipelines, pipeline_stages, lead_statuses — this makes a cross-tenant reference impossible at the database level even if RLS were misconfigured.

## Ownership

`owner_id` on contacts, companies, leads, opportunities; `assignee_id` on tasks. Services verify the user is an active member of the organisation. When a member is removed, the UI forces reassignment of their owned records to another member (or the remover) before removal completes.
