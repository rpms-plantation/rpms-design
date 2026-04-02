# Generate OpenAPI 3.0 API Contract

Generate a complete OpenAPI 3.0 YAML specification for a module service.

## Step 1 — Identify the module

If a module number or name was provided with this command, use that. Otherwise ask:
- Which module? (M1=Plantation, M2=Tree, M3=Tapping, M4=Workforce, M5=Activity, M6=Attendance)

## Step 2 — Load references

1. Read the module's DDL from `database/module-N-*/`
2. Read `plantation-service-openapi.yaml` as the structural reference (reuse shared components pattern)
3. Check CLAUDE.md for the module's framework (Spring Boot vs Quarkus — affects nothing in OpenAPI but useful context)
4. Check the module dependency table — identify which cross-module FKs this module has

## Step 3 — Determine module context

| Module | Path Prefix | Key Entities | Framework |
|--------|-------------|--------------|-----------|
| M1 | `/api/plantation` | plantation, division, field, nursery, annual_snapshot | Spring Boot |
| M2 | `/api/tree` | tree, tree_tag, tree_health_inspection, tree_growth_measurement, disease_incident | Spring Boot |
| M3 | `/api/tapping` | tapping_task, tapping_task_tree_detail, latex_collection_record, quality_test_result | Quarkus |
| M4 | `/api/workforce` | worker, gang, worker_skill, leave_application, training_record, safety_incident | Spring Boot |
| M5 | `/api/activity` | daily_work_plan, daily_activity, material_usage, activity_photo, supervisor_inspection | Quarkus |
| M6 | `/api/attendance` | daily_attendance, attendance_scan_log, attendance_regularization, worker_shift_roster, monthly_attendance_summary | Quarkus |

## Step 4 — Generate the OpenAPI spec

Follow these rules strictly:

### File Structure
```yaml
openapi: 3.0.3
info:
  title: RPMS {Module} Service API
  version: 1.0.0
  description: ...
servers:
  - url: http://localhost:808{N}
    description: Local development
  - url: https://api.rpms.example.com
    description: Production (via API Gateway)
security:
  - BearerAuth: []
tags: [...]
paths: { ... }
components:
  securitySchemes: { BearerAuth }
  parameters: { PageParam, SizeParam, SortParam, LatParam, LonParam, RadiusKmParam, entity path params }
  responses: { BadRequest, Unauthorized, NotFound, Conflict }
  schemas: { all DTOs }
```

### Entity → Endpoint Rules
- Main entities → full CRUD: GET (list + by-id), POST, PUT, PATCH, DELETE
- Immutable tables → GET + POST only (no PUT, DELETE, PATCH)
- Lookup tables → GET only (list all entries, for dropdown population)
- Child entities → nested under parent path (e.g., `/plantations/{id}/divisions/{divId}/fields`)
- Views → GET-only endpoints under a `/reports` or `/analytics` sub-path

### DTO Rules
- Create request DTO: all user-writable fields, no PK, no timestamps, no auto-calculated fields
- Update request DTO: same as create (full replacement via PUT)
- Patch request DTO: all fields optional (partial update via PATCH)
- Response DTO: all columns including PK, timestamps (readOnly), auto-calc fields (readOnly)
- Geometry → `latitude` + `longitude` (never raw geometry)
- Lookup FKs → expose as VARCHAR code (not integer ID)
- JSONB → `type: object, additionalProperties: true, readOnly: true`

### Reuse from plantation-service-openapi.yaml
Copy these shared components verbatim:
- `PageParam`, `SizeParam`, `SortParam`, `LatParam`, `LonParam`, `RadiusKmParam`
- `PageMetadata` schema
- `ErrorResponse` schema
- `BadRequest`, `Unauthorized`, `NotFound`, `Conflict` response refs
- `BearerAuth` security scheme

## Step 5 — Output

Write the file to: `api-contracts/{module}-service-openapi.yaml`

After generating, run `/review` mentally against the output to catch any violations before saving.
