### Screen: Tree Records & Tracking — Tree List Panel (slide-over)

**Platform**: Web (Angular 18, Angular Material `mat-drawer` side-sheet, standalone component)
**Roles**: SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR (full read + edit), SUPERVISOR (read-only)
**Route**: `/plantation/plantations/:plantationId/fields/:fieldId/trees` — rendered in the `trees` named outlet, layered over the (untouched) [Plantation Drill-Down Grid](plantation-division-field-grid.md)
**Data source**: `GET /trees?fieldId=&treeStatus=&healthRating=&page=&size=&sort=`
**See also**: [`composition-pattern.md`](composition-pattern.md)

#### Layout

Right-anchored slide-over, ~55% viewport width on desktop (full-width on mobile breakpoint), overlaying a dimmed but still-visible grid behind it. Opens already scoped/filtered to the field it was launched from, and — if launched from a specific summary stat (e.g. "18 diseased") — pre-filtered to that segment too.

```
                                          ┌───────────────────────────────────┐
                                          │ ✕  Field F-101 · Kelani Estate     │
                                          │ Trees (2,480 live of 2,512 total)  │
                                          ├───────────────────────────────────┤
                                          │ Status:[TAPPING ▾] Health:[All ▾]  │
                                          │ 🔍 Tree code                       │
                                          ├───────────────────────────────────┤
                                          │ Code       Clone    Status  Health │
                                          │ F101-R05-T023 RRIM600 TAPPING GOOD │
                                          │ F101-R05-T024 RRIM600 TAPPING FAIR │
                                          │ F101-R05-T025 RRIM600 DISEASED POOR│
                                          │ ...                                │
                                          │                    ◂ 1 2 … 25 ▸    │
                                          └───────────────────────────────────┘
```

#### Components

| Component | Type | Data Source | Interactions |
|-----------|------|-------------|---------------|
| Tree grid | `mat-table` (@rpms/shared `DataTable`), server-side pagination | `GET /trees?fieldId={fieldId}&...` (`PagedTreeResponse`) | Sort, filter (status/health/clone/search by tree code), paginate; row click → Tree Detail Popup |
| Filter bar | Reactive form | `GET /lookups/tree-statuses`, `GET /lookups/health-ratings` | Debounced → re-query, syncs to query params (`status`, `healthRating`, `page`) so the panel's own state is deep-linkable independent of the grid behind it |
| Panel header | Static + count | Same paged response `totalElements` | Close (✕) → navigates the `trees` outlet to `null`, revealing the grid untouched |
| Map toggle (optional view) | `MapViewer` (@rpms/shared, `ngx-mapbox-gl`) | Same endpoint, `gps_latitude`/`gps_longitude` per tree | Toggle grid/map view of the same filtered tree set; click marker → Tree Detail Popup |
| "+ Register Tree" | Button → `mat-dialog` | `POST /trees` | Opens Tree create form (not part of this drill-down spec — existing create/edit dialog pattern) |

#### State Management

- **Loading**: skeleton rows, panel header count shows placeholder.
- **Empty**: "No trees match these filters" + "Clear filters" action (distinct from "field has zero trees", which shows a "Register the first tree" CTA instead).
- **Error**: retry banner inside the panel; does not affect the grid behind it.
- **Panel-open animation**: standard Material side-sheet slide-in/out; grid behind is inert (`aria-hidden`) but visually present, not unmounted — closing the panel requires no grid re-fetch.

#### Permissions

| Action | SYSTEM_ADMIN | ESTATE_MGR | CONDUCTOR | SUPERVISOR |
|--------|:---:|:---:|:---:|:---:|
| View tree list | ✅ | ✅ | ✅ | ✅ |
| Register new tree | ✅ | ✅ | ✅ | ❌ |
| Bulk status update | ✅ | ✅ | ❌ | ❌ |
| Export tree list (CSV) | ✅ | ✅ | ✅ | ✅ |
