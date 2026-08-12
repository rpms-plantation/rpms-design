### Screen: Tree Records & Tracking — Tree Detail Popup

**Platform**: Web (Angular 18, Angular Material `mat-dialog` in "full-bleed" mode or a wider `mat-drawer` side-sheet stacked over the Tree List Panel — see Layout note)
**Roles**: SYSTEM_ADMIN, ESTATE_MGR, CONDUCTOR (full read + edit), SUPERVISOR (read-only)
**Route**: `/plantation/plantations/:plantationId/fields/:fieldId/trees/:treeId` — rendered in the nested `treeDetail` outlet, layered over the (untouched) [Tree List Panel](tree-list-panel.md), which is itself layered over the (untouched) [Plantation Drill-Down Grid](plantation-division-field-grid.md)
**Data source**: `GET /trees/{treeId}/profile` (`vw_tree_profile`, primary), plus per-tab endpoints below
**See also**: [`composition-pattern.md`](composition-pattern.md)

#### Layout

Wider overlay than the Tree List Panel it sits on top of (~75% viewport on desktop, full-screen on mobile) — stacks visually above the list panel rather than replacing it, so closing it drops straight back to the same scrolled/filtered list. Header carries identity + current status; body is tabbed because the underlying data (growth, panels, health, disease, tags) is genuinely one-tab-per-table, not a single flat form.

```
                                                    ┌─────────────────────────────────┐
                                                    │ ✕  F101-R05-T023 · RRIM600       │
                                                    │ Status: TAPPING  Health: GOOD    │
                                                    │ Girth: 52.3cm  Panel: BI-1        │
                                                    ├─────────────────────────────────┤
                                                    │ [Overview][Growth][Panels]        │
                                                    │ [Health][Disease][Tags][Map]      │
                                                    ├─────────────────────────────────┤
                                                    │  (active tab content)             │
                                                    │                                    │
                                                    └─────────────────────────────────┘
```

#### Components

| Component | Type | Data Source | Interactions |
|-----------|------|-------------|---------------|
| Header identity strip | Static + inline status chip | `GET /trees/{treeId}/profile` | — |
| **Overview** tab | Key-value summary + status timeline | `vw_tree_profile` fields + `GET /trees/{treeId}/status-history` | Click a status-history entry → expands change reason/actor inline |
| **Growth** tab | Line chart (girth over time) + measurement table | `GET /trees/{treeId}/growth-measurements` | Add measurement (dialog) → `POST` |
| **Panels** tab | Timeline/table of tapping panel history | `GET /trees/{treeId}/panels` | Row click → panel detail (`GET /trees/{treeId}/panels/{panelHistoryId}`) |
| **Health** tab | Inspection history table | `GET /trees/{treeId}/health-inspections` | Add inspection (dialog) → `POST` |
| **Disease** tab | Incident table + linked treatments | `GET /trees/{treeId}/disease-incidents`, `GET /trees/{treeId}/treatments` | Row click → incident detail (`GET /trees/{treeId}/disease-incidents/{incidentId}`); "Log Treatment" action |
| **Tags** tab | NFC/RFID/QR tag list + scan stats | `GET /trees/{treeId}/tags` | Shows `last_scanned_at`, `total_scan_count` per tag; "Deactivate Tag" action |
| **Map** tab | Single-point `MapViewer` (@rpms/shared) | `gps_latitude`/`gps_longitude` from profile | Recenter/zoom only — this is a single tree, not a list |
| Mortality banner (conditional) | Alert banner, shown only if `tree_status IN ('DEAD','REMOVED')` | Profile `mortality_date`/`mortality_cause_code` | Links to `GET /trees/{treeId}/mortality` detail |

#### State Management

- **Loading**: header shows skeleton; each tab lazy-loads its own data only when first activated (not all six endpoints fired on open) — this matters because Growth/Panels/Health/Disease can each be long histories for an old tree.
- **Empty** (per tab): "No growth measurements recorded yet" etc. + role-gated "+ Add" CTA.
- **Error**: retry banner scoped to the failed tab only; other tabs remain usable.
- **Closing**: ✕ or Esc navigates only the `treeDetail` outlet to `null` — the Tree List Panel underneath keeps its exact filter/scroll/page state, and the grid behind that is never touched.

#### Permissions

| Action | SYSTEM_ADMIN | ESTATE_MGR | CONDUCTOR | SUPERVISOR |
|--------|:---:|:---:|:---:|:---:|
| View all tabs | ✅ | ✅ | ✅ | ✅ |
| Edit tree profile (status, health rating) | ✅ | ✅ | ✅ | ❌ |
| Add growth measurement | ✅ | ✅ | ✅ | ❌ |
| Add health inspection | ✅ | ✅ | ✅ | ✅ |
| Log disease incident / treatment | ✅ | ✅ | ✅ | ✅ |
| Record mortality | ✅ | ✅ | ❌ | ❌ |
| Deactivate tag | ✅ | ✅ | ❌ | ❌ |
