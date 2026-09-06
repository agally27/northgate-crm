# 01 — Product Definition

## Purpose

A generic, multi-tenant CRM for small and medium-sized organisations that answers five questions at a glance:

1. **Who** are my prospects and customers?
2. **What is happening** with them right now?
3. **What have I communicated** with them?
4. **What opportunities** exist and what are they worth?
5. **What do I need to do next?**

The product competes on clarity and speed of adoption, not on breadth of features.

## Target customer

| Attribute | Definition |
|---|---|
| Organisation size | 1–50 CRM users; typically 1–10 |
| Sectors | Deliberately generic: trades, consultants, agencies, professional services, small retailers, SaaS, property, recruitment, charities, local and service businesses |
| Buyer | Owner-operator or a manager who chose the tool themselves, without an IT department |
| Technical ability | Comfortable with a web browser and a spreadsheet, nothing more |
| Current state | Managing customers in spreadsheets, notebooks, inboxes, or an over-complex CRM they never fully adopted |

**Explicitly not targeted in MVP:** enterprises with dedicated CRM administrators, organisations needing territory management, quota management, multi-currency consolidated forecasting, or CPQ.

## Primary use cases

1. Record a new enquiry (lead) in under 30 seconds, from desktop or phone.
2. See everything known about a person or company on one screen, including the full history.
3. Move a deal through a pipeline and see the total value at each stage.
4. Know what to do today: due and overdue tasks, leads not yet contacted, deals going quiet.
5. Log a call, note, email or meeting against a person in a few clicks.
6. Find any record instantly by name, email, phone or company.
7. Convert a lead into a contact, company and opportunity without re-typing.
8. Tag, filter and export records for a mailing, a report, or a hand-over.
9. Invite a colleague and control what they can see and change.
10. Adapt the CRM to the business: rename pipeline stages, add a custom field, define lead statuses.

## Core value proposition

> "A CRM your whole team will actually use, running in an afternoon, that grows with you without turning into Salesforce."

Supporting pillars:

- **Simple by default.** One pipeline, sensible statuses, and a working dashboard on day one.
- **Flexible by configuration, not by code.** Custom fields, stages, statuses and tags cover most sector differences.
- **One timeline.** Every interaction with a person or company is visible in one chronological feed.
- **Trustworthy.** Tenant isolation, audit trail, export and deletion are first-class from GCRM-1, not bolted on.

## Product principles

1. **Answer the five questions.** Every screen must serve at least one of them or it doesn't ship.
2. **Generic core, configurable edges.** No sector-specific concept lives in the core schema.
3. **Progressive disclosure.** Advanced options are hidden until needed. Empty states teach.
4. **Isolation is a security boundary.** Tenant scoping is enforced in the database and the data layer, never just the UI.
5. **Nothing is silently destroyed.** Soft delete, archive, and audit before hard delete.
6. **Mobile is a first-class reader and note-taker**, not a full admin console.
7. **Prefer boring technology** with long support horizons over novelty.
8. **Build the seam, not the feature.** Automation, AI, billing and integrations are designed as extension points now and implemented later.

## MVP boundaries (summary; full detail in `09-mvp-and-roadmap.md`)

**In:** organisations, users, roles, invitations, contacts, companies, leads with configurable statuses, opportunities, one editable pipeline per organisation, manual activity logging, timeline, tasks, tags, custom fields (text/number/date/select), global search and list filtering, a dashboard, CSV export, audit log, soft delete.

**Out:** email sync, SMS, web forms, automation, AI, billing, public API, reporting builder, multiple pipelines per organisation (architecturally supported, UI deferred), recurring tasks, document storage, calendar sync, mobile native apps.

## Future capabilities (post-MVP, architecture must not prevent)

Communication integrations (Gmail, Outlook, SMS, web forms), automation rules, AI summaries and recommendations, paid plans with entitlements, public REST API with API keys and webhooks, multiple pipelines, saved views, reporting builder, recurring tasks, file attachments, calendar sync, native mobile apps.

## What the CRM deliberately will NOT attempt

- Marketing automation suites, email campaign builders, landing pages.
- Accounting, invoicing, quoting or payments (integrate, don't build).
- Project management, time tracking, help desk / ticketing.
- Inventory, e-commerce, or point-of-sale.
- Territory, quota, commission or forecasting models beyond simple weighted pipeline value.
- Per-record granular permission schemes (record-level sharing rules). Roles are organisation-wide.
- Workflow "builders" with branching logic in MVP. Automation will be rule → action, not a visual programming environment.
- Custom objects / custom entities. Custom fields on the fixed entities are the customisation ceiling for the foreseeable roadmap.
- Self-hosting or on-premise deployment.
