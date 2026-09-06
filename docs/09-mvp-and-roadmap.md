# 09 — MVP Boundary and Implementation Roadmap

## MVP definition

### MUST HAVE (first usable CRM)

**Foundation**
- Sign-up, sign-in (email+password, magic link), email verification, password reset, session management.
- Create organisation; invite members by email; roles owner/admin/manager/member; remove members with record reassignment; transfer ownership.
- Organisation settings: name, currency, timezone, date format, member permission toggles.
- Multi-tenant isolation with RLS + repository scoping; isolation test suite passing in CI.
- Audit log (write path); audit log viewer for owner/admin.
- Soft delete + Recently Deleted (30 days) for contacts, companies, leads, opportunities, tasks, activities.

**CRM**
- Contacts: full field set, custom fields, tags, owner, status, company link, detail page, list with filters, duplicate warning on create.
- Companies: full field set, contacts list, opportunities list, timeline union.
- Leads: configurable statuses (seeded), list with "not yet contacted", detail, conversion to contact/company/opportunity.
- Opportunities: fields, one default pipeline with editable stages (Settings), board with drag-and-drop, list view, won/lost with reasons and customer status effect, stalled badge.
- Activities: manual note/call/email/meeting/message logging; system activities for status/stage changes and conversions; unified timeline on all four entities; global feed.
- Tasks: CRUD, due date/time, priority, assignee, related records, complete/cancel, My Day view, overdue indication.
- Tags and sources management; custom field definitions (all listed types) for the four entities.
- Global search (⌘K) and per-list filters serialised to URL.
- Dashboard: six tiles, pipeline-by-stage panel, leads-needing-attention panel, my tasks, recent activity.
- CSV export per list and full-organisation export; per-contact data export; contact erasure; organisation deletion with grace period.
- Responsive UI, empty/loading/error states, WCAG AA basics, light/dark.

### SHOULD HAVE (important, scheduled right after MVP)
- CSV import with mapping, preview, duplicate strategy.
- Duplicate report and merge for contacts/companies/leads.
- Multiple pipelines UI; per-pipeline currency.
- Saved views and column chooser.
- Task reminders: in-app notification centre and email digest.
- Lost reasons as a configurable list.
- 2FA (TOTP) and per-organisation enforcement (must-have before public launch).
- Terminology setting (rename "Opportunity"/"Customer" labels).
- PWA install; density toggle.
- Multiple emails/phones per contact.
- Bulk edit / bulk delete / bulk tag.

### FUTURE (deliberately excluded)
- Email/calendar sync (Gmail, Outlook), SMS, web forms — GCRM-9.
- Automation rules — GCRM-10.
- Billing and plans — GCRM-11.
- AI features — GCRM-12.
- Public API, API keys, webhooks — with GCRM-9 or as a standalone phase.
- Reporting builder, custom charts — GCRM-7b.
- Recurring tasks; file attachments; document generation; SSO/SAML; custom contact statuses; record-level sharing; custom roles; native mobile apps; organisation slug rename.

## Roadmap

The proposed phases follow the prompt with three adjustments:

1. **Security is not a late phase.** RLS, roles, audit and the isolation suite are built in GCRM-1; GCRM-13 becomes hardening and production readiness, not first security.
2. **GCRM-2 and GCRM-3 are merged** ("CRM data layer" without UI has no acceptance criteria a user can verify), and Leads move earlier since a lead is the first thing a new user enters.
3. **Public API/webhooks** are placed with Communications (GCRM-9) because web forms and integrations need the outbox and key model at the same time.

| Phase | Name | Scope | Exit criteria (acceptance) |
|---|---|---|---|
| **GCRM-0** | Product & architecture | This specification, ADRs, decisions on open items, repo init | Documents reviewed and approved; open decisions in `11` resolved or explicitly deferred; `git init` with first commit |
| **GCRM-1** | Multi-tenant foundation | Project scaffold (Next.js, TS, Drizzle, Tailwind, shadcn), CI, `.env.example`; auth; users; organisations; memberships; invitations; roles/`can()`; `withTenant` + RLS policies + role setup; audit log; outbox; entitlements stub; layout shell, org switcher, settings/general, settings/members | A user can sign up, create an org, invite a colleague who accepts and sees the org; roles enforced; isolation suite tests 1, 5, 8, 9 pass; policy coverage check in CI; audit rows for every auth/membership event; Lighthouse a11y ≥ 90 on shell |
| **GCRM-2** | Contacts & companies | Contacts and companies CRUD, list/filter/search, detail pages, tags, sources, custom fields (definitions + values + validation), soft delete/Recently Deleted, duplicate warning, CSV export per list | All contact/company fields editable; custom field of each type round-trips; global search finds by name/email/phone; export respects filters; isolation tests 2–4, 6 pass for both modules; E2E create → edit → delete → restore |
| **GCRM-3** | Leads | Lead statuses management, leads CRUD, list with quick filters, qualification, lost reason, conversion flow, system activities for status changes | Conversion creates/links contact, company, opportunity in one transaction and re-links activities/tasks; archived status cannot be used or archived while referenced; "not yet contacted" filter correct; isolation tests for leads |
| **GCRM-4** | Opportunities & pipelines | Pipelines/stages settings editor, opportunities CRUD, board with DnD, list, won/lost flows, probability/weighted value, stalled badge, customer status effect | Stage reorder/archival constraints enforced; DnD is keyboard accessible; won sets contact/company to customer; money stored in minor units with correct currency formatting; isolation tests for pipelines/opportunities |
| **GCRM-5** | Activities & tasks | Activities service with fan-out, timeline component, quick-log composer, global feed, tasks CRUD, My Day, overdue, task_completed activity, `last_activity_at` maintenance | An activity logged on an opportunity appears on contact and company timelines once; timeline pagination stable under concurrent inserts; My Day groups correct across timezones; completing task writes activity; isolation tests |
| **GCRM-6** | Dashboard & search polish | Dashboard tiles/panels, period selector, everyone/me toggle, caching; search ranking; per-contact data export; full-org export job; org deletion flow | Every tile reconciles with the corresponding filtered list count; dashboard p95 < 500 ms at 50k contacts seeded; export job produces zip and expires; org deletion honours grace period; isolation test 7 |
| **GCRM-7** | Reporting & should-haves | CSV import, duplicates report and merge, saved views, multiple pipelines, reminders/notifications, lost reasons, bulk actions, terminology, 2FA | Import 10k rows < 60 s with preview; merge preserves all links; 2FA enforceable; notification digest delivered |
| **GCRM-8** | Customisation depth | Custom contact/company statuses, field sections/ordering, per-stage rules (required fields), density, PWA | Rules block stage move with clear message; PWA installable |
| **GCRM-9** | Communications & public API | Integrations module, credentials encryption, Gmail/Outlook per-user sync, outbound email, web forms endpoint, SMS adapter, API keys, `/api/v1`, webhooks | Synced email appears once on correct timelines; only threads with known contacts synced; API conformance tests; webhook signature verified, retries, replay; DPIA completed |
| **GCRM-10** | Automation | Rules tables, trigger catalogue, condition evaluator, actions, scheduled evaluator, run log, loop protection | The two example rules from `07` work end-to-end; runs audited; limits enforced |
| **GCRM-11** | Billing | Stripe integration, plans, subscriptions, usage counters, entitlement enforcement, billing UI, dunning | Plan change updates limits within 1 minute of webhook; downgrade blocks creation not data; no card data touches the app |
| **GCRM-12** | AI | Provider abstraction, summaries, attention lists, follow-up suggestions, draft emails, NL questions via tools, usage metering, org toggle | AI tools cannot read outside caller's tenant (isolation test with adversarial prompts); all writes are confirmed proposals; usage metered |
| **GCRM-13** | Security & production readiness | Pen test remediation, CSP finalisation, backups/restore drill, monitoring/alerting, runbooks, load test, dependency policy, DPA/privacy policy/sub-processor list, status page | Restore drill documented; load test at 3× expected; zero high findings open; incident runbook approved |
| **GCRM-14** | Launch | Marketing site, onboarding polish, sample data, pricing page, support process, analytics (privacy-preserving), beta cohort then GA | Beta feedback triaged; conversion of onboarding flow measured; launch checklist complete |

Estimated sequencing: GCRM-1 through GCRM-6 constitute the MVP. GCRM-7 is the first post-MVP release.

## Definition of done (every phase)

- Unit and integration tests for the phase's services; isolation tests for every new tenant table; E2E for the primary user journey.
- Migrations reviewed for RLS coverage; `pnpm check` (typecheck, lint, tests, policy coverage) green in CI.
- Audit events for every new mutation.
- Docs updated: data model deltas in `04`, ADR for any decision, `.env.example` for any new variable.
- Accessibility pass on new pages.
