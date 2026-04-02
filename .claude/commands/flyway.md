# Generate Flyway Migration Scripts

Split a module's finalized DDL file into versioned Flyway migration scripts.

## Step 1 — Identify the module

If a module number was provided, use that. Otherwise ask which module (M1–M6, or M0 for platform shared objects).

## Step 2 — Load the DDL

Read the module's DDL file:

| Module | DDL Path | Flyway Prefix |
|--------|----------|---------------|
| Platform | (shared extensions, lookups, views, triggers) | V0_xxx |
| M1 | `database/module-1-field-records/plantation_field_records_ddl.sql` | V1_xxx |
| M2 | `database/module-2-tree-records/tree_records_tracking_ddl.sql` | V2_xxx |
| M3 | `database/module-3-tapping-task/tapping_task_monitoring_ddl.sql` | V3_xxx |
| M4 | `database/module-4-workforce/workforce_management_ddl.sql` | V4_xxx |
| M5 | `database/module-5-daily-activity/daily_activity_monitoring_ddl.sql` | V5_xxx |
| M6 | `database/module-6-attendance/attendance_management_ddl.sql` | V6_xxx |

## Step 3 — Parse and split

Read the entire DDL and separate statements into five categories:

### File 1: `V{N}_001__create_{module}_tables.sql`
- All `CREATE TABLE` statements
- Order tables so that referenced tables come before referencing tables (FK dependency order)
- Include column definitions, constraints, PKs, FKs, CHECK constraints
- Include `CREATE TYPE` (enums) before tables that use them
- DO NOT include indexes, views, triggers, or INSERT statements

### File 2: `V{N}_002__create_{module}_indexes.sql`
- All `CREATE INDEX` and `CREATE UNIQUE INDEX` statements
- Include partial indexes and expression indexes
- Order: table alphabetically, then index name

### File 3: `V{N}_003__create_{module}_views.sql`
- All `CREATE OR REPLACE VIEW` statements
- Order: simple views first, then views that reference other views

### File 4: `V{N}_004__create_{module}_triggers.sql`
- All `CREATE OR REPLACE FUNCTION` statements for trigger functions
- All `CREATE TRIGGER` statements
- Keep each function immediately followed by its trigger(s)
- Include `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER` for idempotency

### File 5: `V{N}_005__seed_{module}_lookups.sql`
- All `INSERT INTO lu_*` statements (lookup table seed data)
- Use `INSERT ... ON CONFLICT DO NOTHING` for idempotency
- Order: lookup tables alphabetically

## Step 4 — Add Flyway headers

Each file starts with:
```sql
-- ============================================================================
-- RPMS — Rubber Plantation Management System
-- Migration: V{N}_00X__{description}.sql
-- Module:    {Module Name}
-- Purpose:   {what this migration does}
-- ============================================================================
```

## Step 5 — Validation

Before writing the files, verify:
- [ ] Every statement from the original DDL appears in exactly one migration file
- [ ] No statement is duplicated across files
- [ ] FK dependency order is correct (referenced tables created before referencing tables)
- [ ] `CREATE EXTENSION` statements go in V0_001 (platform), not in module migrations
- [ ] `GRANT` / `REVOKE` permission statements go at the end of V{N}_001

## Step 6 — Output

Write files to: `database/migrations/`

Report a summary: X tables, Y indexes, Z views, W triggers, N lookup inserts extracted.
