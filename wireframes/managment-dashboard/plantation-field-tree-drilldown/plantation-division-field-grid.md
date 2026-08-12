### Screen: Plantation Field Records — Plantation Drill-Down Grid

**Platform**: Web (Angular 18, standalone components, Angular Material `mat-table`)
**Roles**: SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR (full read + edit), SUPERVISOR (read-only)
**Route**: `/plantation/plantations` (primary outlet — persists underneath all overlays in this drill-down)
**Data source**: `GET /plantations`, `GET /plantations/{plantationId}/divisions`, `GET /plantations/{plantationId}/fields`, `GET /plantations/{plantationId}/fields/{fieldId}/tree-summary`
**See also**: [`composition-pattern.md`](composition-pattern.md) for how expansion state and the M1→M2 embed work

#### Layout

Full-width single-panel screen (no split view at this level — the panels come from the overlays, not this screen).

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Plantation Field Records                          [+ New Plantation]     │
│ Region: [dropdown ▾]  Status: [dropdown ▾]  🔍 Search plantation/code    │
├──────────────────────────────────────────────────────────────────────────┤
│ ▾ Code   Name              Region       Area(ha)  Status    ⋮            │
│ ┌────────────────────────────────────────────────────────────────────┐  │
│ │ ▾ PLT-01  Kelani Estate   Central       1,240.5  ACTIVE   [Edit][⋮] │  │
│ │   ┌──────────────────────────────────────────────────────────────┐ │  │
│ │   │ Divisions                                        [+ Division] │ │  │
│ │   │ ▾ Code   Name        Area(ha)  Manager        Active          │ │  │
│ │   │   DIV-A  North Block   420.0   R. Fernando     ✓    [Edit][⋮] │ │  │
│ │   │     ┌──────────────────────────────────────────────────────┐ │ │  │
│ │   │     │ Fields                                     [+ Field] │ │ │  │
│ │   │     │ Code   Clone    Planted  Category  Area  Trees   ⋮   │ │ │  │
│ │   │     │ F-101  RRIM600  2015     MATURE    12.4  ▸ [View]    │ │ │  │
│ │   │     │  └ expanded: 🌳 2,480 live · 2,410 tappable ·         │ │ │  │
│ │   │     │     18 diseased · avg girth 52.3cm    [View Trees →] │ │ │  │
│ │   │     │ F-102  PB260    2019     IMMATURE  8.1   ▸ [View]    │ │ │  │
│ │   │   DIV-B  South Block   380.0   S. Perera      ✓    [Edit][⋮] │ │  │
│ │   └──────────────────────────────────────────────────────────────┘ │  │
│ │ ▸ PLT-02  Maskeliya Estate  West        980.2   ACTIVE   [Edit][⋮] │  │
│ └────────────────────────────────────────────────────────────────────┘  │
│                                                     ◂ 1 2 3 ▸  Page size ▾│
└──────────────────────────────────────────────────────────────────────────┘
```

Three nesting levels, each an independent `mat-table` with `multiTemplateDataRows`, indented and visually distinguished by a subtler background per depth. Only one level of a given branch is expanded-and-scrolled-into-view at a time by default (expanding a new row auto-collapses siblings at the same level, to keep the grid from growing unboundedly tall) — expanding Field rows is the exception, see below.

#### Components

| Component | Type | Data Source | Interactions |
|-----------|------|-------------|---------------|
| Plantation table | `mat-table` (@rpms/shared `DataTable` wrapper) | `GET /plantations?region=&status=&page=&size=` | Sort, filter (region/status/search), paginate, row expand/collapse |
| Division nested table (in expanded Plantation row) | `mat-table` | `GET /plantations/{plantationId}/divisions` | Row expand/collapse; no independent pagination (divisions per plantation are few) |
| Field nested table (in expanded Division row) | `mat-table` | `GET /plantations/{plantationId}/fields?divisionId=` | Row expand/collapse; "View Trees" action opens Tree List Panel overlay |
| Field Tree Summary (in expanded Field row) | `FieldTreeSummaryComponent` — **exported from `@rpms/mod-tree`**, embedded here | `GET /plantations/{plantationId}/fields/{fieldId}/tree-summary` (`vw_field_tree_summary`) | Read-only stat strip; clicking any stat (e.g. "18 diseased") opens Tree List Panel pre-filtered to that segment |
| Toolbar filters | Reactive form controls | `GET /lookups/*` for dropdown options | Debounced filter → re-query top-level table |
| Row action menu (⋮) | `mat-menu` | — | Edit, Deactivate, View Lifecycle History (`GET /plantations/{plantationId}/fields/{fieldId}/lifecycle`) |

#### Field row expansion — bounded by design

Expanding a Field row **never** lists individual trees inline. It shows only the aggregate from `vw_field_tree_summary` (live/tappable/immature/diseased counts, mortality rate, avg girth) — an O(1) payload regardless of field size. Getting to actual tree rows always goes through the "View Trees" action → Tree List Panel (see [`tree-list-panel.md`](tree-list-panel.md)), which is paginated server-side.

#### State Management

- **Loading**: skeleton rows matching the table's column layout, per nesting level independently (expanding a Division shows a Field-table skeleton without blocking the Plantation table).
- **Empty**: "No divisions yet for this plantation" / "No fields yet for this division" + inline "+ Add" CTA, scoped to the empty level only.
- **Error**: inline retry banner within the nested table region that failed — does not collapse or error out parent levels.
- **Expansion restore on load/refresh**: `expandPlantation` / `expandDivision` query params (see composition-pattern.md) are read on init and the corresponding rows pre-expanded, with skeleton shown while their children fetch.

#### Permissions

| Action | SYSTEM_ADMIN | ESTATE_MGR | CONDUCTOR | SUPERVISOR |
|--------|:---:|:---:|:---:|:---:|
| View grid (all levels) | ✅ | ✅ | ✅ | ✅ |
| Create/Edit Plantation | ✅ | ✅ | ❌ | ❌ |
| Create/Edit Division | ✅ | ✅ | ✅ | ❌ |
| Create/Edit Field | ✅ | ✅ | ✅ | ❌ |
| Deactivate Plantation/Division/Field | ✅ | ✅ | ❌ | ❌ |
| View Field Tree Summary | ✅ | ✅ | ✅ | ✅ |
