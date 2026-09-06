# 08 — UI / UX

## Application structure

```text
/sign-in, /sign-up, /invite/{token}, /forgot-password          (public)
/onboarding                                                     (create first organisation)
/{orgSlug}/
   dashboard
   contacts          → contacts/{id}
   companies         → companies/{id}
   leads             → leads/{id}
   opportunities     → board (pipeline) | list  → opportunities/{id}
   tasks
   activities        (global feed)
   reports           (hidden until GCRM-7)
   settings/
      general | members | pipelines | lead-statuses | custom-fields | tags | sources
      import | export | recently-deleted | audit-log
      integrations | api | automation | billing        (hidden until their phases)
/account               (profile, security, sessions, organisation switcher)
```

## Navigation

- **Desktop:** left sidebar (collapsible to icons) with organisation switcher at the top, primary items, and settings at the bottom; top bar with global search (⌘K), "+" quick-create, notifications (should-have), user menu.
- **Mobile (< 768 px):** bottom tab bar with Dashboard, Contacts, Opportunities, Tasks, More; search and "+" as floating actions; sidebar becomes a drawer.
- Breadcrumb on record pages: `Contacts › Jane Smith`.
- Every entity list → detail → edit follows the same pattern so the app is learned once.

## Page hierarchy and patterns

| Pattern | Used by | Description |
|---|---|---|
| List page | contacts, companies, leads, opportunities (list), tasks, activities | Filter bar, search box, column table (TanStack Table), bulk selection, row click opens detail, keyboard navigation |
| Board page | opportunities | Columns per stage, cards show name, company, value, owner avatar, days-in-stage, stalled badge; drag-and-drop with optimistic update; column footers with count and value |
| Detail page | contacts, companies, leads, opportunities | Three-column: details / timeline / related (tasks, opportunities, contacts); inline editing of fields; quick-log composer |
| Sheet / modal form | create and quick edit | Slide-over on desktop, full-screen on mobile; Zod validation with inline errors; unsaved-changes guard |
| Settings page | all settings | Two-level navigation; each list editor (stages, statuses, tags, sources, fields) uses the same sortable list component |

## Responsive behaviour

- Breakpoints: 640 / 768 / 1024 / 1280. Tables collapse to card lists below 768. Three-column detail becomes stacked tabs (Details · Timeline · Related). Board scrolls horizontally with snap.
- Touch targets ≥ 44 px; drag on board has a long-press fallback and a "Move to stage" menu.

## Empty, loading and error states

- **Empty states** teach: "No contacts yet — add your first contact, or import a spreadsheet" with both actions; filtered-empty distinguishes "nothing matches these filters" with a "clear filters" action.
- **Loading:** skeletons matched to layout (never spinners on full pages); streaming server components for detail pages so header appears before timeline; optimistic UI for stage moves, task completion, tag changes with rollback toast on failure.
- **Errors:** inline field errors; toast for action failures with retry; page-level error boundary with request id ("Something went wrong — reference 1a2b3c") and a "try again" button; 404 for records the user cannot see (no distinction between missing and other-tenant).
- **Offline:** banner; read-only cached page still visible; mutations disabled.

## Accessibility

- WCAG 2.2 AA target. Radix primitives supply focus management and ARIA for dialogs, menus, comboboxes.
- Full keyboard operation including the board (arrow keys to move focus, space to pick up/drop, escape to cancel).
- Colour is never the only signal (stage/status also show a label; stalled shows an icon + text).
- Contrast ≥ 4.5:1 in both light and dark themes; colour tokens rather than raw hex for stages/tags with automatic foreground selection.
- Reduced-motion respected; live regions for toasts; form labels always visible.
- Automated axe checks in Playwright on every main page.

## Mobile considerations

- Primary mobile jobs: look up a contact, call/email with one tap (`tel:`/`mailto:`), log a call or note, complete a task, check today's tasks, move a deal.
- Quick-log composer optimised for thumbs; voice-to-text is the OS keyboard's job.
- PWA manifest and install prompt (should-have); no native app in MVP.

## Visual design

- Clean, low-chrome, generous whitespace, one accent colour, neutral greys, system font stack (Inter as optional web font), 8-pt spacing grid, light and dark themes.
- Density toggle (comfortable / compact) for list pages — should-have.
- No dashboards crammed with widgets; six tiles and three panels maximum.
- Language: plain English ("Deal" is not used; "Opportunity" is the term, renamable per organisation as a should-have "terminology" setting for sectors like charities that say "Donor" not "Customer").
