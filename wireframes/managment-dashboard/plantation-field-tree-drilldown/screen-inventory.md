# Screen Inventory — Plantation → Division → Field → Tree Drill-Down

**Modules**: M1 Plantation Field Records (`rpms-mod-plantation`) + M2 Tree Records & Tracking (`rpms-mod-tree`)
**Platform**: Web dashboard (Angular 18, `rpms-shell-web`)
**Pattern**: Hybrid SPA drill-down — inline-expanding grid for bounded hierarchy levels, slide-over/popup for unbounded or detail-heavy levels. See [`composition-pattern.md`](composition-pattern.md) for the routing/composition mechanics behind this — it's meant to be the reference pattern for other modules' drill-downs (Worker→Gang, Tapping Task→Tree Detail, etc.), not a one-off.

This replaces the earlier design of four separate routed pages (Plantations list → Fields page → Trees page → Tree detail page) with one persistent grid screen plus two overlay layers. Nothing here changes the API contracts already defined in `plantation-service-openapi.yaml` / `tree-service-openapi.yaml` — this is purely a client-side composition change.

## Screens

| # | Screen | Type | Owning module | Route | Roles |
|---|---|---|---|---|---|
| 1 | Plantation Drill-Down Grid | List view, inline-expandable rows (3 levels: Plantation → Division → Field) | `@rpms/mod-plantation` | `/plantation/plantations` | SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR, SUPERVISOR (read) |
| 2 | Field Tree Summary (expanded row content) | Embedded summary panel | `@rpms/mod-tree` (embedded into M1's grid) | *(no route — inline in Screen 1)* | Same as above |
| 3 | Tree List Panel | Slide-over / side-sheet, paginated + filterable grid | `@rpms/mod-tree` | `/plantation/plantations/:plantationId/fields/:fieldId/trees` (aux outlet `trees`) | SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR, SUPERVISOR |
| 4 | Tree Detail Popup | Modal / large side-sheet, tabbed | `@rpms/mod-tree` | `/plantation/plantations/:plantationId/fields/:fieldId/trees/:treeId` (aux outlet `treeDetail`) | SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR, SUPERVISOR |

## Screens explicitly NOT collapsed into the grid

- **Tree create/edit form** — stays a full reactive-form dialog (`mat-dialog`), not a grid row. Registering a tree (clone, planting method, nursery source, row/sequence, tags) is a write-heavy workflow that doesn't belong inline in a read-oriented grid.
- **Field create/edit form** — same reasoning, stays a dialog launched from the grid toolbar, not inline.
- **Disease hotspot / mortality analytics** (`vw_disease_hotspot`, `vw_mortality_analysis`) — these are cross-field/cross-plantation analytical views, not part of the single-plantation drill-down; they remain a separate Analytics screen under `/tree/analytics`.

## Screen specs

- [`plantation-division-field-grid.md`](plantation-division-field-grid.md) — Screen 1 + 2
- [`tree-list-panel.md`](tree-list-panel.md) — Screen 3
- [`tree-detail-popup.md`](tree-detail-popup.md) — Screen 4
- [`composition-pattern.md`](composition-pattern.md) — routing/deep-link/cross-module composition mechanics shared by all four
- [`drilldown-flow.mermaid`](drilldown-flow.mermaid) — state diagram of the full interaction flow
