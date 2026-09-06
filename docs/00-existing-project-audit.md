# 00 — Existing Project Audit (GCRM-0)

**Audit date:** 2026-09-04
**Location audited:** `/Users/capgal27/crm-app`

## Verdict

**This is a new, empty repository.** The directory contains no files, no hidden files, no `.git` directory, no configuration, no code, and no documentation. Nothing exists that could constrain or inform the architecture. Everything in the rest of this specification is therefore **Proposed** unless explicitly marked **Confirmed**.

## Audit results

| Area | Finding | Status |
|---|---|---|
| Framework | None present | Confirmed absent |
| Language | None present | Confirmed absent |
| Frontend architecture | None present | Confirmed absent |
| Backend architecture | None present | Confirmed absent |
| Database | No schema, no migrations, no connection config | Confirmed absent |
| Authentication | None present | Confirmed absent |
| Authorisation | None present | Confirmed absent |
| Hosting / deployment | No `vercel.json`, Dockerfile, CI config, or IaC | Confirmed absent |
| Existing components | None | Confirmed absent |
| Existing services | None | Confirmed absent |
| Environment configuration | No `.env*`, no `.env.example` | Confirmed absent |
| Testing framework | None | Confirmed absent |
| Package / dependency structure | No `package.json`, lockfile, or workspace config | Confirmed absent |
| API architecture | None | Confirmed absent |
| Current database schema | None | Confirmed absent |
| Existing security mechanisms | None | Confirmed absent |
| UI / design system | None | Confirmed absent |
| Existing documentation | None (this `docs/` folder is the first artefact) | Confirmed absent |
| Version control | Not a git repository | Confirmed absent |

## Host machine toolchain (Confirmed, informs but does not dictate the stack)

| Tool | Version | Relevance |
|---|---|---|
| macOS (Darwin) | 25.6.0 | Development host |
| Node.js | v25.9.0 | Available runtime for a TypeScript stack |
| npm | 11.12.1 | Available |
| pnpm | 11.11.0 | Available; preferred package manager |
| PostgreSQL (client + Homebrew server) | 17.10 | Local database for development and integration tests |
| SQLite | 3.51.0 | Available; not proposed for production |
| Python | 3.9.6 | Available; not proposed for this product |
| Vercel CLI | 59.1.4 | Suggests Vercel is a viable deployment target |
| GitHub CLI (`gh`) | 2.90.0 | Suggests GitHub for source hosting |
| Docker | Not installed | Cannot rely on Testcontainers or Docker Compose locally |
| Supabase CLI | Not installed | Supabase not currently set up |
| Go, Rust, Bun, Deno, Yarn | Not installed | Not candidates without further setup |

## Implications

1. There is no legacy to migrate, integrate with, or protect. The stack can be chosen on merit.
2. Integration tests must run against the locally installed PostgreSQL 17 rather than a Docker container, unless Docker is installed later (see `10-testing-strategy.md`).
3. Version control must be initialised before GCRM-1 begins (`git init`, `.gitignore`, first commit of these documents).
4. No environment secrets exist yet. A `.env.example` must be authored in GCRM-1.

## Missing information (not guessed)

The following was not discoverable from the repository and needs a human decision or answer before implementation. Each is tracked in `11-risks-and-open-decisions.md`.

- Preferred hosting provider and region (data residency matters for GDPR).
- Managed Postgres provider (Neon, Supabase, RDS, Railway, self-hosted).
- Whether email delivery is required in GCRM-1 for invitations and password reset (implies a transactional email provider).
- Company/brand name for the product, which affects tenancy naming and email templates.
- Target launch geography (affects currency defaults, date formats, privacy regime).
