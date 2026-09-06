# 02 — Proposed Architecture and Technology Stack

Nothing in this document is Confirmed as existing in the repository. Items marked **Confirmed** refer only to tooling present on the development host (see `00-existing-project-audit.md`).

## Technology stack

| Layer | Proposal | Status | Rationale | Alternatives considered |
|---|---|---|---|---|
| Language | TypeScript (strict) end-to-end | Proposed | Single language for UI, server, schema and tests; Node 25 present (**Confirmed**) | Go/Rust backend (not installed, splits the team) |
| Runtime | Node.js 22 LTS target (developed on 25) | Proposed | Long-term support for a commercial product | Bun (not installed) |
| Package manager | pnpm 11 (**Confirmed** installed) | Proposed | Fast, strict, workspace-ready | npm |
| Web framework | Next.js (App Router), React Server Components, Server Actions for mutations, Route Handlers for API | Proposed | Full-stack in one deployable; SSR for fast first paint; Vercel CLI present (**Confirmed**) suggests aligned hosting | Remix/React Router, SvelteKit, separate SPA + Fastify/NestJS |
| Database | PostgreSQL 16/17 (17 **Confirmed** locally) | Proposed | Row-Level Security, JSONB for custom fields, full-text search, mature | MySQL (no RLS), MongoDB (weak relational integrity) |
| ORM / query layer | Drizzle ORM + drizzle-kit migrations | Proposed | SQL-transparent, typed, RLS-friendly (easy to set session settings per transaction), light runtime | Prisma (harder to combine with `SET LOCAL` + RLS), Kysely (more manual) |
| Authentication | Better Auth (self-hosted, Postgres adapter) with email+password, magic link, and OAuth (Google/Microsoft) | Proposed, **open decision** | Data stays in our database (GDPR), built-in organisation/invitation/session primitives, no per-user vendor pricing | Auth.js v5 (less batteries), Clerk/WorkOS (vendor lock, per-MAU cost, user PII off-platform) |
| Validation | Zod schemas shared by forms, server actions and API | Proposed | Single source of truth for input validation | Valibot |
| UI | Tailwind CSS + shadcn/ui (Radix primitives), Lucide icons | Proposed | Accessible primitives, owned code, modern look, fast to build | MUI, Mantine |
| Forms / data | React Hook Form + Zod; TanStack Table for lists; TanStack Query only where client caching is needed | Proposed | Standard, well-supported | |
| Background jobs | Postgres-backed queue (e.g. `pg-boss`) in MVP; evaluate Inngest/Trigger.dev when automation lands | Proposed | No extra infrastructure; durable; enough for reminders, exports, audit fan-out | Redis/BullMQ (adds Redis) |
| Email (transactional) | Resend or Postmark via a thin `Mailer` interface | Proposed, **open decision** | Needed for invitations and password reset in GCRM-1 | SES |
| Hosting | Vercel for the app; managed Postgres (Neon or Supabase-Postgres-only) in an EU or UK region | Proposed, **open decision** | Zero-ops for a small team; region choice is a privacy decision | Fly.io / Railway (Docker; Docker not installed locally), AWS |
| Observability | Structured JSON logs (pino), Sentry for errors, OpenTelemetry-compatible tracing later | Proposed | | |
| Testing | Vitest (unit/integration), Playwright (E2E), local Postgres 17 for DB tests | Proposed | Docker is **not** installed; Testcontainers is not an option today | |
| CI | GitHub Actions (gh CLI **Confirmed**) | Proposed | | |

## Repository layout (proposed, single application for MVP)

A single Next.js application is sufficient for MVP. A workspace (`apps/`, `packages/`) is introduced only when a second deployable (public API worker, mobile app) exists.

```text
crm-app/
├── docs/                      # this specification, ADRs
├── src/
│   ├── app/                   # Next.js App Router
│   │   ├── (auth)/            # sign-in, sign-up, invite acceptance
│   │   ├── (app)/[orgSlug]/   # all tenant-scoped pages
│   │   │   ├── dashboard/
│   │   │   ├── contacts/
│   │   │   ├── companies/
│   │   │   ├── leads/
│   │   │   ├── opportunities/ # includes board (pipeline) and list views
│   │   │   ├── tasks/
│   │   │   ├── activities/
│   │   │   ├── reports/       # post-MVP
│   │   │   └── settings/
│   │   └── api/
│   │       ├── auth/          # auth handlers
│   │       ├── internal/      # first-party endpoints used by the UI (cron, jobs)
│   │       └── v1/            # public API (post-MVP; reserved)
│   ├── modules/               # domain modules; each owns schema slice, service, validation, tests
│   │   ├── tenancy/           # organisations, memberships, invitations, tenant context
│   │   ├── identity/          # users, sessions, auth adapter
│   │   ├── contacts/
│   │   ├── companies/
│   │   ├── leads/
│   │   ├── opportunities/
│   │   ├── pipelines/
│   │   ├── activities/
│   │   ├── tasks/
│   │   ├── tags/
│   │   ├── custom-fields/
│   │   ├── search/
│   │   ├── dashboard/
│   │   ├── audit/
│   │   ├── export/
│   │   ├── events/            # domain event bus (seam for automation, AI, webhooks)
│   │   ├── entitlements/      # plan limits (seam for billing)
│   │   └── integrations/      # seam for communications providers
│   ├── db/                    # drizzle client, migrations, RLS policies, seed
│   ├── lib/                   # shared utilities, errors, ids, dates, money
│   └── components/            # shared UI (design system wrappers)
├── tests/
│   ├── unit/
│   ├── integration/           # DB + service tests
│   ├── isolation/             # tenant isolation suite (mandatory, blocks merge)
│   └── e2e/                   # Playwright
├── .env.example
└── package.json
```

## Layering rules

```text
UI (Server Components / Client Components)
   │  calls
Server Actions / Route Handlers            ← auth check, parse input (Zod), build TenantContext
   │  calls
Module services (contacts.service.ts …)    ← business rules, permissions, domain events
   │  calls
Repositories (contacts.repo.ts …)          ← the ONLY code that touches Drizzle/SQL
   │  runs inside
withTenant(ctx, tx => …)                   ← opens a transaction, SET LOCAL app.org_id, applies RLS
   │
PostgreSQL with Row-Level Security          ← enforces organisation_id on every tenant table
```

Rules:

1. UI never imports repositories. Services never import React.
2. Every repository method takes a `TenantContext` as its first argument. There is no repository method that can run without one, except in the `platform` module (super-admin) which is separately audited.
3. Every write goes through a service so that audit logging and domain events cannot be skipped.
4. Every request handler resolves `TenantContext` once from the session and the `[orgSlug]` segment, verifies membership, and passes it down. No handler reads `organisationId` from a request body or query string.

## TenantContext (proposed shape)

```ts
type TenantContext = {
  organisationId: string;   // UUID; verified membership
  userId: string;
  role: 'owner' | 'admin' | 'manager' | 'member';
  requestId: string;        // correlation id for logs/audit
  now: () => Date;          // injectable clock for tests
};
```

## Request flow for a mutation (example: create contact)

1. Client submits a form → Server Action `createContactAction(formData)`.
2. Action loads session; loads membership for `orgSlug`; builds `TenantContext`; parses input with `CreateContactSchema`.
3. Action calls `contactsService.create(ctx, input)`.
4. Service checks `can(ctx, 'contact:create')`, runs duplicate detection, calls `contactsRepo.insert(ctx, data)` inside `withTenant`.
5. Repository inserts with `organisation_id = ctx.organisationId` (never from input). RLS additionally rejects any row whose `organisation_id` differs from the session setting.
6. Service writes an `audit_log` row and emits `contact.created` on the in-process event bus (same transaction, outbox table for durable consumers).
7. Action revalidates the path and returns a typed result (`{ ok: true, id }` or `{ ok: false, errors }`).

## Domain event bus (the seam for later phases)

An `events` module defines typed domain events (`lead.created`, `opportunity.stage_changed`, `task.completed`, …). In MVP the only subscribers are the audit log and the activity timeline ("status change" activities). Later phases subscribe without touching core services:

- Automation (GCRM-10) → rule engine subscribes to events.
- Webhooks (GCRM-9/API) → outbox rows dispatched to subscribers.
- AI (GCRM-12) → background enrichment/summary jobs.
- Communications (GCRM-9) → inbound integrations *emit* activities through the same services.

Events are written to an `outbox` table in the same transaction as the change, and a worker drains it. This guarantees at-least-once delivery for future consumers without redesign.

## Identifier strategy

UUIDv7 primary keys generated in the application (time-ordered, index-friendly, safe to expose). Slugs for organisations in URLs. No sequential integers exposed externally.

## Configuration and environments

`.env.example` documents every variable. Environments: `local`, `preview` (per-branch on Vercel), `production`. Secrets never committed. Database URLs per environment; the application connects as a **non-superuser role that is subject to RLS** (see `06-security-and-privacy.md`).
