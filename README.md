# Keel CRM

A simple, modern, multi-tenant CRM for small and medium-sized businesses of any kind: trades, consultants, agencies, professional services, retailers, SaaS, property, recruitment, charities and local service businesses.

It answers five questions: who are my prospects and customers, what is happening with them, what have I communicated, what opportunities exist, and what do I need to do next.

## Status

**Discovery complete, implementation not started.** This repository currently contains:

- [`docs/`](docs/README.md) — the full product and architecture specification (GCRM-0), including the data model, multi-tenant security model, MVP boundary, roadmap and open decisions.
- [`prototype/crm-prototype.html`](prototype/crm-prototype.html) — a self-contained click-through prototype on sample data. Open it in a browser; nothing is saved.

No application code, migrations or configuration exist yet. Implementation (GCRM-1, multi-tenant foundation) begins after the specification is approved and the open decisions in [`docs/11-risks-and-open-decisions.md`](docs/11-risks-and-open-decisions.md) are answered.

## Proposed stack

TypeScript, Next.js, PostgreSQL with row-level security, Drizzle ORM, Better Auth, Tailwind and shadcn/ui, pnpm. All proposed, none confirmed; see [`docs/02-proposed-architecture.md`](docs/02-proposed-architecture.md).
