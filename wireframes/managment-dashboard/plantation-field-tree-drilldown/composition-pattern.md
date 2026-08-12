# Composition Pattern: Inline-Expand + Overlay Drill-Down

This is the mechanics doc referenced by all four screens in this drill-down. Treat it as the reference pattern to reuse for other modules' hierarchies (e.g. Worker → Gang → Worker Detail in M4, Tapping Task → Tree Detail in M3) — don't reinvent it per module.

## Why not four routed pages, and why not one giant expanded tree either

Four separate pages (the original design) loses grid position/filters/scroll on every hop and reloads a component tree each time — it's SPA-safe but UX-heavy. Fully expanding everything inline (Plantation → Division → Field → all Trees) breaks down at the Field→Tree boundary because a field can hold thousands of trees (see `tree_census_summary`) and Tree detail has too much content (growth history, panel history, health inspections, disease incidents, tags) to fit in a table row. The hybrid below keeps the grid as the permanent "home" and layers overlays only where the data is genuinely detail-heavy or unbounded.

## Three techniques, one per transition

### 1. Plantation → Division → Field: inline expansion, no routing

Angular Material `mat-table` with `multiTemplateDataRows`. Expanding a Plantation row reveals a nested `mat-table` of Divisions in the detail row; expanding a Division row reveals its Fields the same way. Pure component state — `Set<plantationId>` / `Set<divisionId>` of expanded IDs — because these lists are small (a plantation has single-digit divisions, single-to-low-double-digit fields) and cheap to keep mounted.

**Deep-linkability**: mirror the expanded-ID sets into query params, not path segments — `?expandPlantation=5&expandDivision=12`. Query params because this is view state, not a distinct resource/screen (no back-button stop needed for every row toggle — that would make Back annoying to use). Use `Router.navigate(..., { queryParamsHandling: 'merge', replaceUrl: true })` on toggle so expand/collapse doesn't spam browser history, but the URL is still shareable and survives refresh (`ngOnInit` reads `queryParamMap` once and re-expands).

### 2. Field → Tree List: named (auxiliary) router outlet, not query params

This *is* a distinct resource with its own filters/pagination, so it gets a real route segment and its own back-button stop — but it renders as a slide-over, not a full-page swap. Angular's auxiliary/named outlets are the built-in mechanism for exactly this: a secondary outlet can navigate independently while the primary outlet (the grid) stays mounted untouched.

```
app.routes.ts (mod-plantation shell integration)
{
  path: 'plantations',
  component: PlantationGridPageComponent,   // primary outlet — the grid, always present
  children: [
    {
      path: 'plantations/:plantationId/fields/:fieldId/trees',
      outlet: 'trees',
      loadComponent: () => import('@rpms/mod-tree').then(m => m.TreeListPanelComponent)
    }
  ]
}
```

Resulting URL: `/plantation/plantations(trees:plantations/5/fields/42/trees?status=TAPPING&page=0)`. The grid component is untouched by this navigation — no re-fetch, no scroll reset. Closing the panel is `Router.navigate([{ outlets: { trees: null } }])`.

### 3. Tree List → Tree Detail: nested named outlet inside the panel

Same technique one level deeper — a `treeDetail` outlet nested under the `trees` outlet, rendering as a modal/large side-sheet stacked over the tree list panel:

```
{
  path: 'plantations/:plantationId/fields/:fieldId/trees',
  outlet: 'trees',
  loadComponent: () => import('@rpms/mod-tree').then(m => m.TreeListPanelComponent),
  children: [
    {
      path: 'plantations/:plantationId/fields/:fieldId/trees/:treeId',
      outlet: 'treeDetail',
      loadComponent: () => import('@rpms/mod-tree').then(m => m.TreeDetailPopupComponent)
    }
  ]
}
```

Closing the popup navigates only the `treeDetail` outlet away; the tree list panel underneath keeps its filter state and scroll position because it was never touched.

## Cross-module UI composition (M1 embeds M2)

The Field row's expanded content (tree count/status/health summary) and both overlay panels are Tree data, owned by `@rpms/mod-tree` (M2) — not `@rpms/mod-plantation` (M1). M1's grid component must not reimplement tree-summary logic; it embeds M2's exported pieces:

- `@rpms/mod-tree` exports a standalone `FieldTreeSummaryComponent` (`<rpms-field-tree-summary [fieldId]="field.fieldId" />`) that M1's expanded Field row template consumes directly, backed by `GET /plantations/{plantationId}/fields/{fieldId}/tree-summary` (`vw_field_tree_summary`).
- `@rpms/mod-tree` also exports the `trees` / `treeDetail` outlet route definitions (`TREE_DRILLDOWN_ROUTES`) that `rpms-shell-web` (or `mod-plantation`'s own routing config) registers as children of the plantation grid route.

This is a new kind of module coupling — UI-level, not just shell-level route composition — and should be called out explicitly wherever module boundaries are documented (`modular-architecture-implementation-guide.md`) so it doesn't get rediscovered ad hoc by whoever builds Worker→Gang next. The database ownership rule ("single writer, many readers") already permits M1 to *read* tree data; this pattern is the UI-layer equivalent — M1 *renders* M2's exported view, it doesn't own or duplicate the query.

## State summary

| Transition | Mechanism | URL changes? | New history entry? | Component reused? |
|---|---|---|---|---|
| Expand/collapse Plantation or Division row | Component `Set` state + query params | Yes (query param) | No (`replaceUrl: true`) | Grid never remounts |
| Open/close Tree List panel | Named outlet (`trees`) | Yes (path segment) | Yes | Grid never remounts |
| Open/close Tree Detail popup | Nested named outlet (`treeDetail`) | Yes (path segment) | Yes | Grid + tree list never remount |
| Refresh browser at any point | — | Router restores exactly the outlets/query params present in the URL | — | — |
