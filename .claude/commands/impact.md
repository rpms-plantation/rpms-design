# Impact Analysis — Schema Change Blast Radius

Analyze what happens if a database table or column is added, modified, or deprecated. Identify every artifact that needs to change.

## Step 1 — Identify the change

Ask for (skip any already provided):
1. **Table name** — which table is affected?
2. **Change type** — ADD column, MODIFY column type, ADD table, DEPRECATE column, ADD FK
3. **Details** — the specific change (e.g., "add `sustainability_score NUMERIC(5,2)` to `tapping_task`")

## Step 2 — Identify the owning module

Look up which module owns the table using the DDL files:
- M1: plantation, division, field, nursery, annual_snapshot, lu_* (plantation lookups)
- M2: tree, tree_tag, tree_health_inspection, tree_growth_measurement, disease_incident, lu_* (tree lookups)
- M3: tapping_task, tapping_task_tree_detail, latex_collection_record, quality_test_result, lu_* (tapping lookups)
- M4: worker, gang, worker_skill, leave_application, training_record, safety_incident, lu_* (workforce lookups)
- M5: daily_work_plan, daily_activity, material_usage, activity_photo, supervisor_inspection, lu_* (activity lookups)
- M6: daily_attendance, attendance_scan_log, attendance_regularization, worker_shift_roster, monthly_attendance_summary, lu_* (attendance lookups)

## Step 3 — Trace the blast radius

For the identified change, check each artifact type:

### 3a. Flyway Migration (REQUIRED)
- A new Flyway migration script is needed: `V{N}_00X__add_{description}.sql`
- The original DDL file is NOT modified (it's finalized)

### 3b. OpenAPI Spec
- Does the module's OpenAPI spec exist? If yes:
  - Does the change affect request DTOs? (new writable column → add to create/update schema)
  - Does the change affect response DTOs? (any new column → add to response schema)
  - Is it a computed column? (→ add as readOnly)
  - Is it a geometry column? (→ add as lat/lon pair, not raw geometry)
  - Is it a JSONB column? (→ add as object with additionalProperties)
  - Is it a lookup FK? (→ expose as VARCHAR code)

### 3c. Avro Event Schemas
- Does any event for this module include fields from this table?
- If adding a column: should it be added to the event payload?
  - If yes: add as OPTIONAL field with default (BACKWARD compatibility)
  - Update the .avsc file
  - Update topic-registry.yaml if new consumers are affected

### 3d. Views
- Search all module DDLs for views that SELECT from this table
- List each affected view and whether it needs to be recreated

### 3e. Triggers
- Search for triggers that fire on this table
- Check if the new column should be included in trigger calculations

### 3f. Cross-Module Impact
- Search all OTHER module DDLs for FK references to this table
- If the change affects a referenced column (PK, FK target), list every downstream table
- Check if other modules' OpenAPI specs or Avro schemas need updating

### 3g. Frontend Impact (non-artifact, informational)
- Angular: which components/forms would need the new field?
- KMP: which screens or SQLDelight queries would need updating?

## Step 4 — Generate the impact report

```markdown
# Impact Analysis: {change description}

## Change Summary
- Table: `{table_name}` (Module {N} — {module_name})
- Change: {description}
- Severity: LOW / MEDIUM / HIGH

## Artifacts to Update

| # | Artifact | File Path | Change Needed | Status |
|---|----------|-----------|---------------|--------|
| 1 | Flyway migration | database/migrations/V{N}_00X__... | CREATE: new migration | ⬜ TODO |
| 2 | OpenAPI spec | api-contracts/{module}-service-openapi.yaml | ADD field to response DTO | ⬜ TODO |
| 3 | Avro schema | api-contracts/events/{module}/{Event}.avsc | ADD optional field | ⬜ TODO |
| 4 | View | (in DDL) | RECREATE view with new column | ⬜ TODO |
| ... | ... | ... | ... | ... |

## Cross-Module Impact
- {Module X}: {why it's affected}
- {Module Y}: {why it's affected}

## No Impact
- {List artifacts confirmed NOT affected and why}

## Recommended Execution Order
1. {first artifact to update}
2. {second}
3. ...
```

## Step 5 — Output

Write to: `docs/impact-analysis/{date}-{change-description}.md`
