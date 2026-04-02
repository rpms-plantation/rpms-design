# Review Design Artifact

Review the specified design artifact for correctness and convention compliance.

## Step 1 — Identify what to review

If a file path was provided with this command, use that. Otherwise, check `git diff --name-only` for recently changed files. If nothing is obvious, ask which artifact to review.

## Step 2 — Determine artifact type and load references

**If reviewing an OpenAPI YAML** (`api-contracts/*.yaml`):
1. Read the module's DDL from `database/module-N-*/`
2. Read `plantation-service-openapi.yaml` as the reference pattern (if reviewing a different module)
3. Apply the OpenAPI checklist below

**If reviewing an Avro schema** (`api-contracts/events/*.avsc`):
1. Read the event catalog in CLAUDE.md
2. Check namespace, naming, and EventMetadata compliance

**If reviewing a Flyway migration** (`database/migrations/V*`):
1. Read the source DDL for that module
2. Verify the migration prefix matches the module number
3. Check that the split follows the 5-file convention

**If reviewing an ADR** (`architecture/architecture-decisions/ADR-*.md`):
1. Read an existing accepted ADR (e.g., ADR-002 or ADR-003) for format reference
2. Check all required sections are present

## Step 3 — OpenAPI Review Checklist

Run every check. Report violations with the exact path/line and the expected fix.

### Schema Mapping (DDL → OpenAPI)
- [ ] Every DDL table has corresponding CRUD endpoints (unless it's a lookup — lookups get GET-only)
- [ ] Every DDL column appears in the response DTO (no silently dropped columns)
- [ ] Column types map correctly: `INTEGER` → `integer`, `NUMERIC(p,s)` → `number/double`, `BOOLEAN` → `boolean`, `TIMESTAMP` → `string/date-time`, `DATE` → `string/date`, `TEXT/VARCHAR` → `string`
- [ ] `SERIAL`/`BIGSERIAL` PKs are `readOnly: true` in response schemas

### Geometry Columns
- [ ] Geometry columns are exposed as `latitude: number (double)` + `longitude: number (double)` — NEVER raw WKT, WKB, or GeoJSON
- [ ] No field named `geom`, `geometry`, `gps_point`, or `boundary` appears in DTOs

### JSONB Columns
- [ ] JSONB columns (`ai_analysis_result`, `ai_quality_assessment`, etc.) typed as `object` with `additionalProperties: true`
- [ ] JSONB columns marked `readOnly: true` (AI services write these, not the REST API)

### Lookup FK Columns
- [ ] Lookup FK columns expose the VARCHAR natural key code, NOT the integer FK ID
- [ ] Example: `tappingSystem: "S/2 d2"` not `tappingSystemId: 7`
- [ ] Each lookup has a GET-only endpoint returning all entries for dropdowns

### Immutable Tables
- [ ] Immutable tables (`scan_log`, `*_change_log`, `*_snapshot`) have GET and POST only
- [ ] No PUT, DELETE, or PATCH endpoints exist for these

### Pagination
- [ ] All list endpoints have `page`, `size`, `sort` query parameters
- [ ] Responses use the wrapper: `{ content: [], totalElements, totalPages, page, size }`
- [ ] `page` default is `0`, `size` default is `20`, `size` max is `100`

### Security
- [ ] Global `security: [ BearerAuth: [] ]` is declared
- [ ] `BearerAuth` security scheme defined as `type: http, scheme: bearer, bearerFormat: JWT`

### Timestamps
- [ ] `createdAt` and `updatedAt` are present in response DTOs and marked `readOnly: true`
- [ ] Not present in request/create DTOs

### Spatial Filtering
- [ ] Endpoints for spatially-aware tables include optional `lat`, `lon`, `radiusKm` query params

### Naming Conventions
- [ ] Properties use `camelCase` (not `snake_case`)
- [ ] Paths use `kebab-case` (e.g., `/api/tapping/tapping-tasks/{taskId}`)
- [ ] Path prefix matches module: `/api/plantation/...`, `/api/tree/...`, `/api/tapping/...`

### Auto-Calculated Fields
- [ ] Trigger-calculated fields (`completion_pct`, `dry_rubber_kg`, `work_hours`, `late_minutes`, `overtime_minutes`, `current_member_count`) are `readOnly: true`
- [ ] These are NOT accepted in create/update request DTOs

### Error Responses
- [ ] Standard error responses defined: 400 (BadRequest), 401 (Unauthorized), 404 (NotFound), 409 (Conflict)
- [ ] Error schema includes: `timestamp`, `status`, `error`, `message`, `path`

## Step 4 — Report

Present findings as:
1. **PASS** — checks that passed (brief summary)
2. **FAIL** — violations found (with exact location, what's wrong, and the fix)
3. **WARN** — potential issues that need human judgment

End with a compliance score: X/Y checks passed.
