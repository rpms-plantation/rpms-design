# Generate Wireframe Specification

Design wireframe specifications for a module's Angular dashboard screens and/or Android mobile screens.

## Step 1 — Identify scope

Ask for (skip any already provided):
1. **Module** — which module? (M1–M6)
2. **Platform** — web dashboard (Angular), mobile (Android/KMP), or both?
3. **Screen** — specific screen, or generate the full module screen inventory?

## Step 2 — Load references

1. Read the module's DDL — tables define what data each screen shows
2. Read the module's OpenAPI spec (if available) — endpoints define what actions are possible
3. Read the Keycloak role matrix (if available) — roles define who sees what
4. Check ADR-004 (Angular) for dashboard conventions or ADR-005 (KMP) for mobile conventions

## Step 3 — Generate screen inventory

For the module, enumerate all screens by role:

### Dashboard Screens (Angular — ESTATE_MANAGER, CONDUCTOR, CLERK)
For each main entity in the module:
- **List view** — data table with filters, sort, pagination, spatial filter, export
- **Detail view** — full entity display with related entities, timeline, map
- **Create/Edit form** — reactive form with validation, lookup dropdowns, spatial picker
- **Dashboard/Analytics** — charts from views, KPI cards, map overlays

### Mobile Screens (Android — TAPPER, SUPERVISOR, COLLECTOR)
For each field workflow:
- **Task list** — today's assigned tasks, status indicators, offline badge
- **Task execution** — step-by-step workflow (scan NFC → enter data → capture photo → submit)
- **Summary** — daily recap, sync status

## Step 4 — Generate wireframe specs

For each screen, output a specification in Mermaid or structured markdown:

```markdown
### Screen: {Module} — {Screen Name}

**Platform**: Web / Mobile / Both
**Roles**: {who sees this screen}
**Route**: `/app/{module}/{screen-path}` (web) or `{Module}NavGraph/{screen}` (mobile)
**Data source**: `{API endpoint}` or `{SQLDelight query}` (offline)

#### Layout
{Describe the layout: header, sidebar context, main content area, action bar}

#### Components
| Component | Type | Data Source | Interactions |
|-----------|------|-------------|-------------|
| {entity} table | DataTable (@rpms/shared) | GET /api/{module}/{entities} | Sort, filter, paginate, row-click → detail |
| Map overlay | MapViewer (@rpms/shared) | Same endpoint + lat/lon | Click marker → detail, draw polygon filter |
| KPI cards | Card row | GET /api/{module}/analytics/... | Click → filtered list |
| ... | ... | ... | ... |

#### Form Fields (for create/edit screens)
| Field | Type | Validation | Source |
|-------|------|------------|--------|
| {fieldName} | text / select / date / number / map-picker | required, min, max, pattern | DDL column / lookup endpoint |
| ... | ... | ... | ... |

#### State Management
- Loading state: skeleton loader
- Empty state: illustration + "No {entities} found" + create CTA
- Error state: retry banner
- Offline state (mobile): cached data badge, queue indicator

#### Permissions
| Action | SYSTEM_ADMIN | ESTATE_MGR | CONDUCTOR | SUPERVISOR | TAPPER |
|--------|:---:|:---:|:---:|:---:|:---:|
| View list | ✅ | ✅ | ✅ | ✅ | ❌ |
| Create | ✅ | ✅ | ✅ | ❌ | ❌ |
| Edit | ✅ | ✅ | ❌ | ❌ | ❌ |
| Delete | ✅ | ❌ | ❌ | ❌ | ❌ |
```

## Step 5 — Output

Write to: `wireframes/module-{N}-{name}/`
- `screen-inventory.md` — full list of screens with roles and routes
- `{screen-name}.md` — individual screen specifications
- `{screen-name}.mermaid` — visual layout diagram (optional, for complex screens)

Keep wireframes as specifications, not pixel-perfect designs. They define WHAT appears on each screen and HOW users interact — the Angular/Compose implementation team handles the visual design.
