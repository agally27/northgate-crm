# 05 — Functional Specification (Contacts → Dashboard)

Covers prompt sections 6–15. Everything is Proposed.

## 6. Contact management

**Fields:** first name, last name, email, phone, mobile, address (line 1, line 2, city, region, postcode, country), company (link), job title, website, notes (free "about" text), tags, source, owner, status, custom fields, do-not-contact flag. See `04-data-model.md` for types.

**Behaviours**
- Create from: the Contacts list, the global "+" quick-add, a company page (pre-linked), lead conversion, CSV import (should-have).
- Company field is a combobox that searches existing companies and offers "Create company '{typed}'" inline.
- Phone numbers are normalised to E.164 using the organisation's default country; the raw input is preserved and displayed.
- Emails are lowercased and trimmed. Multiple emails/phones are **not** supported in MVP (one email, one phone, one mobile). A `contact_emails` table is the future path; noted as a should-have.
- Contact detail page: header (name, title, company, owner, status, tags), left column details + custom fields, centre timeline, right column open tasks and opportunities.
- `last_activity_at` updated whenever an activity is logged against the contact.

**Duplicate detection**

Detection runs at three moments:

1. **On create/edit (synchronous, advisory):** as the user types an email or phone, a debounced lookup returns exact matches on normalised email or phone within the tenant. The form shows "Possible duplicate: Jane Smith (Acme)" with a link. Creation is not blocked (owner/admin can set "block exact email duplicates" in settings, default off, because many businesses legitimately share addresses like `info@`).
2. **On import (batch):** rows matching an existing contact by email are, per the user's choice, skipped, updated, or created as duplicates. The import preview shows counts before commit.
3. **Duplicates report (asynchronous, should-have):** a settings page lists candidate pairs scored by: exact email (100), exact phone/mobile (90), same normalised full name + same company (70), trigram similarity of name ≥ 0.6 + same email domain (50). Pairs above 70 are shown by default.

**Merge (should-have, manager+):** choose a surviving record; field-by-field pick; activities, tasks, opportunities, taggings, opportunity_contacts re-pointed to the survivor; the loser is hard-deleted; an audit row records the merge with the loser's snapshot. Leads and companies get the same merge flow.

## 7. Company management

**Fields:** name, website, domain (derived), phone, email, address, industry, size, description, status, source, owner, tags, custom fields.

**Behaviours**
- Company page shows its contacts (with quick "add contact"), open opportunities with total value, timeline (union of company activities and its contacts' activities, distinguished by a small avatar/label), tasks.
- Contacts belong to at most one company in MVP. Contact → company is many-to-one; a contact moving to a new company simply changes `company_id`; history is preserved via an automatic `status_change`-type activity ("Moved from Acme to Beta").
- Duplicate detection: exact normalised name, exact domain. Suggest existing company when a new contact's email domain matches a company domain (excluding public webmail domains).
- Deleting a company never deletes its contacts. The UI offers "also delete N contacts" as a separate, explicit checkbox.

## 8. Lead management

**Lifecycle:** driven by the organisation's `lead_statuses` list, seeded as:

```text
New → Contacted → Qualified → Interested → Converted
                                 ↘ Lost (from any open status)
```

Businesses can rename, reorder, add, colour, and archive open statuses. The `converted` and `lost` kinds are fixed in meaning but renamable ("Won" vs "Converted", "Disqualified" vs "Lost").

**Fields:** name, email, phone, mobile, company name (text), job title, website, status, source, owner, qualification (budget/authority/need/timeline free-text + score 0–100), description (the enquiry), lost reason, tags, custom fields.

**Behaviours**
- Leads list defaults to open statuses, sorted newest first, with a "Not yet contacted" quick filter (status = default status and no outbound activity).
- Status change creates a `status_change` activity and emits `lead.status_changed`.
- Moving to a `lost` status requires a lost reason (configurable free text; a `lost_reasons` list is a should-have).
- Leads are **not** auto-created as contacts. The lead is a lightweight, unqualified record; conversion is the deliberate act of promoting it.

**Conversion process** (`POST convert`, single transaction):

1. Dialog shows: **Contact** (create new from lead fields, or link an existing contact found by email/phone match), **Company** (create from `company_name`, link existing by domain/name match, or none), **Opportunity** (optional: name defaults to "{Company or Contact} — {source}", pipeline default, first open stage, value, expected close date).
2. Service creates/links records; copies custom fields where a definition with the same key exists on the target entity type; copies tags applicable to the target.
3. Lead activities are **re-linked** (their `contact_id`/`company_id`/`opportunity_id` are set) so the history follows the person; the `lead_id` stays set for traceability. Open tasks on the lead are re-pointed to the contact.
4. Lead status set to the `converted` status; `converted_*_id` and `converted_at` set; lead becomes read-only except for notes.
5. Contact `status` set to `prospect` (or `customer` if the organisation setting "converted leads are customers" is on, default off).
6. Emits `lead.converted`.

## 9. Opportunities

**Fields:** name, contact, company, additional contacts, value + currency, pipeline, stage, probability (defaults from stage; overridable), expected close date, owner, description, source, tags, custom fields, created/updated timestamps, stage entered at.

**Weighted value** = value × probability / 100, shown in pipeline totals.

**Won**
- Move to a stage of kind `won` (drag on board or select in form). Requires confirming the final value and close date (defaults to today).
- Effects: `status = won`, `won_at` set, `probability = 100`; linked contact and company `status` set to `customer` (if currently prospect/lead); `opportunity.won` emitted; a `stage_change` activity written; auto-archive after N days (org setting, default 30) so the board stays clean while history remains.

**Lost**
- Move to a stage of kind `lost`; lost reason required.
- Effects: `status = lost`, `lost_at`, `probability = 0`; contact/company status unchanged; `opportunity.lost` emitted; auto-archive as above.

**Reopen:** manager+ may move a won/lost opportunity back to an open stage; statuses recalculated; audited. Customer status on contact/company is not automatically reverted (a note is added suggesting review).

**Stalled detection (MVP, read-only):** an opportunity is "stalled" when `now - stage_entered_at > stage.rotting_after_days` (default 14 for open stages). Shown as a badge on the board and counted on the dashboard. This is the seam for the "unchanged for 14 days → create task" automation later.

## 10. Custom pipelines

Schema supports many pipelines per organisation from day one (`pipelines`, `pipeline_stages`). MVP UI exposes one default pipeline with a stage editor in Settings:

- Add / rename / reorder (drag) / recolour / archive stages.
- Set probability per stage; set stalled threshold per stage.
- Exactly one won and one lost stage required (more allowed later, e.g. "Lost – price", "Lost – timing").
- Archiving a stage with opportunities prompts to move them to another stage first.
- Reordering uses integer `position` with gap renumbering in a transaction (deferrable unique constraint).

**Should-have:** multiple pipelines (e.g. "New business" and "Renewals"), pipeline selector on the board, per-pipeline default currency.

**Future "rules"** (e.g. required fields per stage, stage entry validations) will be stored as jsonb `rules` on `pipeline_stages` and evaluated in the opportunities service. The column is reserved, not created, in MVP.

Nothing sector-specific is hard-coded: the seed is a neutral Qualification → Proposal → Negotiation set and is fully editable.

## 11. Activity timeline

One `activities` table, one component, rendered on contact, company, lead, opportunity pages and as a global "Activity" feed.

**Types and how they are created**

| Type | Created by | Editable/deletable |
|---|---|---|
| note | user | yes (author, or manager+) |
| call | user (with direction, duration, outcome in body) | yes |
| email | user (manual log in MVP; provider sync later) | manual: yes; synced: no |
| meeting | user | yes |
| message | user (SMS/WhatsApp/etc. logged manually); integrations later | as email |
| status_change | system on lead status change, contact/company status change | no |
| stage_change | system on opportunity stage move / won / lost | no |
| task_completed | system when a linked task is completed | no |
| system | system (created, converted, merged, imported, reassigned) | no |

**Relationships:** an activity references any combination of contact, company, lead, opportunity (at least one). The activities service **fans out** links: logging a call on an opportunity with a primary contact stores `opportunity_id`, `contact_id`, and the contact's `company_id`, so all three timelines show it once. `actor_user_id` records who did it; `task_id` links completions.

**Rendering:** grouped by day, newest first, with type icon, actor avatar, relative time, subject, expandable body, and "related to" chips linking to the other entities. Pinned notes float to the top. Filters: type, user, date range. Infinite scroll, 50 per page, keyset pagination on `(occurred_at, id)`.

**Quick log:** a composer at the top of every timeline with tabs Note / Call / Email / Meeting, "occurred at" defaulting to now, and an optional "create follow-up task" toggle.

## 12. Tasks and follow-ups

- **Create:** from the Tasks page, any record page, the quick-log composer, the global "+" menu. Fields: title, description, due date (+ optional time), priority, assignee (default me), related records, reminder time (schema now; notification delivery is a should-have).
- **Status:** open → completed (or cancelled). Completing writes a `task_completed` activity on linked records and emits `task.completed`.
- **Overdue:** derived (`open AND due_at < now()`), shown red, counted on the dashboard.
- **My Day (Tasks page default view):** Overdue · Today · Tomorrow · This week · Later · No date; filter by assignee (mine / everyone, manager+ sees team), priority, related entity type. Keyboard: `c` complete, `n` new.
- **Reminders (should-have):** in-app notification centre + email digest at a user-chosen time; push later.
- **Recurring tasks (future):** RRULE stored on the parent; on completion the next occurrence is materialised by the tasks service. Column exists in MVP so no migration is needed later.

## 13. Search and filtering

**Global search** (⌘K / Ctrl-K): single input, queries contacts, companies, leads, opportunities, tasks via Postgres `tsvector` columns plus trigram fallback, returns grouped top-5 per entity with keyboard navigation. Also matches phone digits and email prefixes. Tenant-scoped via RLS; results ranked by `ts_rank` then `last_activity_at`.

**Entity lists** share one filter framework:

| Filter | Contacts | Companies | Leads | Opportunities | Tasks | Activities |
|---|---|---|---|---|---|---|
| Owner / assignee | ✔ | ✔ | ✔ | ✔ | ✔ | actor |
| Status | ✔ | ✔ | ✔ (lead status) | ✔ (open/won/lost) | ✔ | — |
| Tag | ✔ | ✔ | ✔ | ✔ | — | — |
| Date (created, updated, last activity) | ✔ | ✔ | ✔ | ✔ | due | occurred |
| Pipeline / stage | — | — | — | ✔ | — | — |
| Value range | — | — | — | ✔ | — | — |
| Source | ✔ | ✔ | ✔ | ✔ | — | — |
| Company | ✔ | — | — | ✔ | — | — |
| Custom field (equals / contains / range) | ✔ | ✔ | ✔ | ✔ | — | — |
| Type | — | — | — | — | — | ✔ |
| Text search within list | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |

Filters serialise to the URL query string so views are shareable and bookmarkable. Saved views are a should-have (a `saved_views` table storing the query string + column config + owner + visibility).

Pagination: keyset, 50 per page; column sort on indexed columns only.

## 14. Customisation foundation

| Capability | MVP | Notes |
|---|---|---|
| Custom fields (text, textarea, number, currency, date, boolean, select, multiselect, url, email, phone) | ✔ | Per entity type; show in list; required flag; validation generated from definitions |
| Tags | ✔ | Colour, restrict to entity types |
| Custom pipeline stages | ✔ | One pipeline UI; many in schema |
| Custom lead statuses | ✔ | |
| Configurable sources | ✔ | |
| Organisation settings (currency, timezone, date format, member permissions toggles) | ✔ | |
| Multiple pipelines | should-have | |
| Saved views / column chooser | should-have | |
| Custom contact/company statuses | future | Same pattern as lead statuses |
| Custom lost reasons | should-have | |
| Field-level display order, sections | future | |
| Custom entities | never (see product definition) | |

Design rule: any list that a business is likely to rename (stages, statuses, sources, tags) is a tenant-scoped table with `position`, `colour`, `archived_at`, and referential protection; anything else is a custom field.

## 15. Dashboard

Layout: a top row of stat tiles, a middle row with two panels, a bottom row for "my work". Period selector: This week / This month / This quarter / Custom. Manager+ can toggle "Everyone / Just me"; members see their own.

**Tiles (with delta vs previous period):**
1. Total contacts
2. New leads (created in period)
3. Open opportunities (count) and open pipeline value (sum of value, plus weighted)
4. Won in period (count, value)
5. Lost in period (count, value)
6. Lead → opportunity conversion rate (leads converted in period ÷ leads created in period) and win rate (won ÷ (won + lost) closed in period)

**Panels:**
- Pipeline by stage: horizontal bars of count and value per open stage, with stalled count badge.
- Leads needing attention: not yet contacted, or no activity for 7+ days, oldest first (top 10, link to filtered list).

**My work:**
- Tasks due today and overdue (top 10, complete inline).
- Recent activity feed (last 20 across the organisation, or mine).

Queries are simple aggregates over indexed columns and are cached per organisation for 60 seconds. No reporting builder in MVP; "Reports" nav entry is hidden until GCRM-7 adds it.
