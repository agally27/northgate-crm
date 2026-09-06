# 11 — Risks and Open Architectural Decisions

## Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Cross-tenant data leak through a missed scope | Medium without controls | Critical (commercial and legal) | Dual enforcement (repository + RLS), composite FKs, generated isolation matrix, policy coverage CI check, Semgrep rule, pen test |
| R2 | RLS + connection pooling misconfiguration (session-scoped `SET` leaking tenant across pooled connections) | Medium | Critical | Only `SET LOCAL` inside transactions; test that a query outside a transaction returns nothing; pooler in transaction mode |
| R3 | Serverless cold starts and connection limits on Vercel + Postgres | Medium | Medium (latency) | Pooler (Neon/PgBouncer), small connection counts, RSC streaming; fallback: move to a long-running Node host (Fly/Railway) — same codebase |
| R4 | Lead-as-separate-entity causes duplicate people (lead and contact for the same person) | Medium | Medium (user trust) | Conversion links by email/phone match; duplicate report spans leads and contacts; clear UI copy |
| R5 | JSONB custom fields limit querying/reporting | Low–Medium | Medium | GIN index; expression indexes for fields marked "show in list"; cap per plan; revisit with EAV only if reporting demands it |
| R6 | Polymorphic taggings without FK integrity leave orphans | Low | Low | Service-level cleanup on hard delete; nightly orphan sweep job |
| R7 | Scope creep toward enterprise features | High | High (product) | "Will NOT attempt" list in `01`; MVP boundary in `09`; every feature must map to one of the five questions |
| R8 | Choice of auth library proves limiting (SSO, org features) | Low–Medium | Medium | Auth kept behind an `identity` module interface; sessions in our DB so migration is data-preserving |
| R9 | GDPR obligations underestimated (sub-processors, residency, DPA) | Medium | High | Decisions D6–D8 before GCRM-1 deploys real data; DPIA before GCRM-9/12 |
| R10 | Background jobs on serverless hosting are awkward (no long-running worker) | Medium | Medium | pg-boss driven by a cron-triggered endpoint in MVP; dedicated worker (Fly/Railway) or Inngest when automation lands |
| R11 | Single-region deployment limits future customers requiring other residency | Low (MVP) | Medium | Region as configuration; multi-region is a later platform project, not a schema change |
| R12 | Node 25 on the dev machine vs LTS in production | Low | Low | `engines` field and `.nvmrc` pinned to 22 LTS; CI on 22 |
| R13 | Email deliverability for invitations/reset | Medium | Medium (onboarding) | Reputable transactional provider; SPF/DKIM/DMARC set up in GCRM-1 |
| R14 | Money handling errors (floats, currency mixing) | Low | High | Minor units as bigint, currency per opportunity, no cross-currency sums in MVP (dashboard sums only in org default currency, others listed separately) |
| R15 | Search relevance poor with Postgres FTS alone | Low–Medium | Medium | Trigram + FTS + phone-digit index; external search only if measured need |

## Open architectural decisions (need a human answer before or during GCRM-1)

| # | Decision | Options | Recommendation | Needed by |
|---|---|---|---|---|
| D1 | Web framework | Next.js App Router · Remix/React Router · SvelteKit | Next.js (ecosystem, Vercel alignment, RSC streaming) | GCRM-1 start |
| D2 | Auth library | Better Auth · Auth.js v5 · Clerk/WorkOS | Better Auth (self-hosted data, org primitives, no per-MAU fees) | GCRM-1 start |
| D3 | ORM | Drizzle · Prisma · Kysely | Drizzle (RLS/`SET LOCAL` friendly, SQL-transparent) | GCRM-1 start |
| D4 | Hosting | Vercel + managed Postgres · Fly.io · Railway · AWS | Vercel + Neon (EU/UK region); revisit if R3/R10 bite | GCRM-1 deploy |
| D5 | Managed Postgres provider | Neon · Supabase (Postgres only) · RDS · Railway | Neon (branching for previews, pooler, PITR) | GCRM-1 deploy |
| D6 | Data residency region | UK · EU (Ireland/Frankfurt) · US | Depends on target market; **must be answered**, no default | before real data |
| D7 | Transactional email provider | Resend · Postmark · SES | Postmark or Resend | GCRM-1 (invitations) |
| D8 | Error reporting / analytics providers (sub-processors) | Sentry (EU region) · self-hosted · none | Sentry EU | GCRM-1 |
| D9 | Default currency, locale, timezone, date format | GBP/en-GB/Europe/London · USD/en-US · per-tenant only | Per-tenant at onboarding with a default inferred from browser locale; product default GBP/en-GB unless market says otherwise | GCRM-1 |
| D10 | Lead as a separate entity vs contact with status | Separate (this spec) · unified | Separate, as specified; revisit only if R4 materialises in beta | GCRM-3 |
| D11 | Customer as an entity vs status | Status on contact/company (this spec) · separate Customer table | Status; a "Customers" filtered view covers the need | GCRM-2 |
| D12 | Members' default visibility | All records visible to all members (this spec) · owner-only for members | All visible; toggle for editing others' records only | GCRM-1 |
| D13 | Product / company name and domain | — | Needed for slugs, email templates, cookies | GCRM-1 |
| D14 | Object storage for exports/imports | Vercel Blob · S3 · Cloudflare R2 | R2 or S3 in the same region as D6 | GCRM-2 (export) |
| D15 | Background job runner | pg-boss + cron endpoint · Inngest · Trigger.dev | pg-boss for MVP; re-evaluate at GCRM-10 | GCRM-5 (reminders) |
| D16 | AI provider | Anthropic · OpenAI · Azure-hosted | Anthropic Claude via provider interface | GCRM-12 |
| D17 | Billing provider | Stripe · Paddle (merchant of record) · Lemon Squeezy | Stripe unless MoR tax handling is preferred | GCRM-11 |
| D18 | Pricing tiers and limits | as proposed in `07` | Validate with prospects during beta | GCRM-11 |
| D19 | Open-source licensing of the codebase | proprietary · source-available | Proprietary by default | GCRM-0 |
| D20 | Whether to require 2FA at launch | optional · enforced for admins · enforced for all | Optional in MVP, enforceable per org, required for platform admins | GCRM-7 |

## Information that was missing and not guessed

- Business/brand identity (D13).
- Target market geography and therefore residency (D6) and defaults (D9).
- Budget appetite for third-party services (auth, email, error reporting) versus self-hosting.
- Any existing customers or beta users whose data would need importing (affects import priority).
- Whether the founder team has a preferred stack. The recommendation above is based only on tooling found on the host machine.
