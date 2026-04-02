# Generate Module Documentation

Auto-generate a comprehensive README for a module's database directory or other design artifacts.

## Step 1 — Identify the target

If a module or path was provided, use that. Otherwise ask what to document:
- A module's database schema (most common)
- The overall api-contracts directory
- The architecture decisions collection
- A cross-module reference guide

## Step 2 — For Database Schema Documentation

Read the module's DDL file from `database/module-N-*/` and generate a README.md containing:

### Section 1: Module Overview
- Module name and number
- One-paragraph business description (what does this module manage?)
- Framework assignment (Spring Boot or Quarkus) and why
- Flyway prefix (V{N}_xxx)
- Repo: `rpms-mod-{module}`

### Section 2: Table Summary
A table listing every table in the DDL:

| Table | Type | Rows (Est.) | Description |
|-------|------|-------------|-------------|
| {table_name} | Core / Lookup / Analytics / Log | Low/Med/High | {one-line purpose} |

### Section 3: Entity Relationships
- Which tables have FKs to tables in OTHER modules (cross-module dependencies)
- Which tables have FKs within this module (internal relationships)
- Present as a bulleted dependency list, not a full ER diagram (the HTML artifact has that)

### Section 4: Key Design Patterns
Identify and document patterns used in this module's DDL:
- Immutable tables (if any) — which ones and why
- Auto-calculated fields — list each trigger-computed column with its formula
- JSONB columns — what AI/ML data they store
- Geometry columns — what spatial data they represent (Point, LineString, Polygon)
- TimescaleDB hypertables (if any) — partition scheme
- GENERATED columns — formulas

### Section 5: Views
List each view with:
- View name
- Purpose (what dashboard/report it powers)
- Key JOINs (which tables, including cross-module)

### Section 6: Triggers
List each trigger with:
- Trigger name and timing (BEFORE/AFTER INSERT/UPDATE)
- What it auto-calculates or enforces
- Source table → affected column

### Section 7: Lookup Tables
List each `lu_*` table with:
- Table name
- Number of seed entries
- Sample values (first 3-5 entries)
- Which core table(s) reference it

### Section 8: Permissions
- Which PostgreSQL service account owns (writes to) these tables
- Which service accounts have read-only access

## Step 3 — Output

Write to: `database/module-N-*/README.md`

Keep the README factual and reference-oriented — it's a developer quick-reference, not prose documentation.
