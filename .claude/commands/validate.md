# Validate Cross-Artifact Consistency

Cross-check all design artifacts against each other for inconsistencies and drift.

## Step 1 — Identify scope

If a specific module was provided, validate only that module's artifacts. Otherwise validate everything.

## Step 2 — Run validation checks

### Check 1: DDL ↔ OpenAPI Consistency
For each module that has both a DDL and an OpenAPI spec:
- [ ] Every DDL table has corresponding endpoints in the OpenAPI spec
- [ ] Every DDL column appears in the response DTO (no missing columns)
- [ ] Column types match (DDL `INTEGER` → OpenAPI `integer`, DDL `TIMESTAMP` → OpenAPI `string/date-time`, etc.)
- [ ] FK relationships reflected in path nesting or query params
- [ ] Immutable tables in DDL → GET+POST only in OpenAPI
- [ ] Auto-calc trigger columns in DDL → `readOnly` in OpenAPI
- [ ] Lookup tables in DDL → GET-only endpoints in OpenAPI

### Check 2: DDL ↔ Flyway Consistency
For each module that has both a DDL and Flyway migrations:
- [ ] Every DDL statement appears in exactly one Flyway migration file
- [ ] No orphan Flyway statements that aren't in the DDL
- [ ] Table creation order in Flyway respects FK dependencies
- [ ] Flyway prefix matches module number (V1_xxx for M1, etc.)
- [ ] Extensions (PostGIS, TimescaleDB, etc.) are in V0_001, not in module migrations

### Check 3: Event Catalog ↔ Avro Schemas Consistency
For each event in the CLAUDE.md event catalog:
- [ ] A corresponding .avsc file exists in `api-contracts/events/{module}/`
- [ ] Avro namespace matches `com.rpms.events.{module}`
- [ ] Partition key field exists in the Avro schema
- [ ] EventMetadata is the first field
- [ ] topic-registry.yaml entry exists with correct producer and consumers

### Check 4: Event Catalog ↔ OpenAPI Consistency
For events triggered by REST operations:
- [ ] If `PlantationCreated` event exists → OpenAPI has `POST /plantations` endpoint
- [ ] If `FieldStatusChanged` event exists → OpenAPI has `PATCH /fields/{id}` with status field
- [ ] State-change events reference status values that exist in the DDL's CHECK constraints or lookup tables

### Check 5: Cross-Module FK Consistency
Verify the cross-module FK table from RPMS_PROJECT_CONTEXT.md:
- [ ] M1 → M2: `field.field_id` referenced in tree DDL
- [ ] M1 → M3: `field.field_id` referenced in tapping DDL
- [ ] M1 → M4: `plantation_id`, `division_id`, `field_id` referenced in workforce DDL
- [ ] M2 → M3: `tree.tree_id` referenced in tapping DDL
- [ ] M4 → M3: `worker.worker_id` referenced in tapping DDL
- [ ] M4 → M5: `worker.worker_id` referenced in activity DDL
- [ ] M4 → M6: `worker.worker_id` referenced in attendance DDL
- [ ] M3 → M5: `tapping_task.task_id` referenced in activity DDL
- [ ] M5 → M6: `daily_activity.activity_id` referenced in attendance DDL

### Check 6: ADR ↔ Artifact Consistency
- [ ] ADR-002 says M1/M2/M4 = Spring Boot, M3/M5/M6 = Quarkus → OpenAPI server ports and descriptions consistent
- [ ] ADR-003 says Avro + BACKWARD compatibility → all .avsc schemas have no removed/renamed fields across versions
- [ ] ADR-006 says V0 prefix for platform → no module migrations use V0_xxx

### Check 7: Naming Convention Consistency
Across all artifacts:
- [ ] OpenAPI properties use camelCase (not snake_case)
- [ ] OpenAPI paths use kebab-case
- [ ] Avro field names use camelCase
- [ ] DDL column names use snake_case
- [ ] Kafka topics use `rpms.{module}.{kebab-case-event}`
- [ ] Avro files use PascalCase (e.g., `TappingTaskCompleted.avsc`)

## Step 3 — Report

Present findings grouped by severity:

**ERRORS** — Inconsistencies that will cause runtime failures:
- Missing columns, wrong types, broken FK references

**WARNINGS** — Inconsistencies that indicate drift:
- Missing artifacts that should exist, naming convention violations

**INFO** — Observations:
- Artifacts that exist but haven't been cross-validated because their counterpart doesn't exist yet

End with a consistency score and the list of artifacts that need attention.
