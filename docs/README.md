# Generic CRM — Specification (GCRM-0)

Discovery milestone output, 2026-09-04. **Status: awaiting approval. No code, migrations or configuration exist in this repository yet.**

## Documents

| File | Contents |
|---|---|
| [00-existing-project-audit.md](00-existing-project-audit.md) | Audit of the (empty) repository and host toolchain; Confirmed vs Proposed |
| [01-product-definition.md](01-product-definition.md) | Purpose, target customer, use cases, value proposition, principles, non-goals |
| [02-proposed-architecture.md](02-proposed-architecture.md) | Stack, repository layout, layering, TenantContext, request flow, event bus |
| [03-multi-tenancy-and-roles.md](03-multi-tenancy-and-roles.md) | Tenancy model, tenant identification, memberships, RLS, roles matrix, cross-tenant protection, audit, deletion, export |
| [04-data-model.md](04-data-model.md) | Every table, field, index, constraint, deletion/archival behaviour |
| [05-functional-specification.md](05-functional-specification.md) | Contacts, companies, leads, opportunities, pipelines, timeline, tasks, search, customisation, dashboard |
| [06-security-and-privacy.md](06-security-and-privacy.md) | Security model, isolation tests, GDPR requirements and open legal decisions |
| [07-future-platform-seams.md](07-future-platform-seams.md) | Communications, automation, AI, billing, public API and webhooks — integration points only |
| [08-ui-ux.md](08-ui-ux.md) | Application structure, navigation, page patterns, responsive, states, accessibility |
| [09-mvp-and-roadmap.md](09-mvp-and-roadmap.md) | MUST / SHOULD / FUTURE, phased roadmap GCRM-0…14 with acceptance criteria |
| [10-testing-strategy.md](10-testing-strategy.md) | Test layers, isolation suite, performance budgets, CI pipeline |
| [11-risks-and-open-decisions.md](11-risks-and-open-decisions.md) | Risk register and the 20 decisions that need a human answer |

## Files to create before implementation starts (GCRM-1 entry checklist)

Documents and configuration, in order. None of these are application code.

1. `docs/adr/0001-stack.md` … `0006-…` — Architecture Decision Records for D1–D5, D10–D12 once answered.
2. `docs/decisions.md` — a filled-in copy of the D1–D20 table with the chosen answers and dates.
3. `.gitignore`, `README.md` (root), `LICENSE` (per D19), `CODEOWNERS`.
4. `.nvmrc` / `engines` pin (Node 22 LTS), `package.json` with `packageManager: pnpm@11`.
5. `.env.example` listing every variable with a comment (database URLs for `crm_app` and `crm_migrator`, auth secret, email provider, storage, error reporting, `APP_URL`, `DEFAULT_REGION`).
6. `docs/runbooks/local-setup.md` — creating the local Postgres roles and databases (`crm_dev`, `crm_test_template`) on the installed PostgreSQL 17.
7. `docs/runbooks/migrations.md` — how RLS policies are generated and checked for every new tenant table.
8. `docs/security/threat-model.md` — expanded from `06`, with STRIDE table per surface.
9. `docs/privacy/sub-processors.md` and `docs/privacy/data-map.md` — populated as providers are chosen.
10. `.github/workflows/ci.yml` — the pipeline in `10`, initially running only lint/typecheck until code exists.
11. `.github/PULL_REQUEST_TEMPLATE.md` — with the definition-of-done checklist from `09`.
12. `git init` and an initial commit containing the above.

## Approval gate

Implementation (GCRM-1: multi-tenant foundation) begins only after explicit approval of this specification and answers to at least D1–D9 and D13 in `11-risks-and-open-decisions.md`.
