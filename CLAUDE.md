# CLAUDE.md — rpms-design

> Read this file at the start of every session. It is the authoritative context for this repo.

## What This Repo Is

`rpms-design` is the **design-only source of truth** for the RPMS (Rubber Plantation Management System). It contains database schemas, architecture diagrams, ADRs, API contracts, Avro event schemas, Flyway migration templates, wireframes, and technical specifications.

RPMS uses a **modular pluggable architecture** (ADR-006) with 10 repositories. This is one of them — the design repo. Implementation code lives in separate repos.

## What This Repo Is NOT

This repo contains **zero application source code**. NEVER create Java, Kotlin, TypeScript, Python, or any runnable application files here. Implementation goes in the module repos (`rpms-mod-*`) and platform repo (`rpms-platform`).

## Repository Map (10 Repos)

```
rpms-plantation (GitHub Organization)
├── rpms-design              ← THIS REPO — design artifacts only
├── rpms-platform            ← Shared libs, event schemas, gateway, infra
├── rpms-mod-plantation      ← M1: Spring Boot + Angular lib + KMP + Flyway V1_xxx
├── rpms-mod-tree            ← M2: Spring Boot + Angular lib + KMP + Flyway V2_xxx
├── rpms-mod-tapping         ← M3: Quarkus + Angular lib + KMP + Flyway V3_xxx
├── rpms-mod-workforce       ← M4: Spring Boot + Angular lib + KMP + Flyway V4_xxx
├── rpms-mod-activity        ← M5: Quarkus + Angular lib + KMP + Flyway V5_xxx
├── rpms-mod-attendance      ← M6: Quarkus + Angular lib + KMP + Flyway V6_xxx
├── rpms-shell-web           ← Angular shell (thin compositor)
└── rpms-shell-mobile        ← KMP/Compose shell (thin compositor)
```

## Session Startup

1. Read this file
2. Identify which module(s) the task targets
3. Read the DDL: `database/module-N-*/[module]_ddl.sql`
4. Read relevant ADR(s) if the task involves architecture decisions
5. Check `api-contracts/` for existing OpenAPI specs
6. Check `RPMS_PROJECT_CONTEXT.md` for full project context if needed

## Directory Structure

```
rpms-design/
├── CLAUDE.md                         ← You are reading this
├── RPMS_PROJECT_CONTEXT.md           ← Full project context (modules, stack, conventions)
├── architecture/
│   ├── rpms_high_level_architecture.html
│   ├── rpms_artifact_storage_strategy.html
│   ├── modular-architecture-implementation-guide.md
│   └── architecture-decisions/       ← ADR-001 through ADR-006
├── database/
│   ├── module-1-field-records/       ← .sql + .html + .mermaid + README
│   ├── module-2-tree-records/
│   ├── module-3-tapping-task/
│   ├── module-4-workforce/
│   ├── module-5-daily-activity/
│   └── module-6-attendance/
├── api-contracts/                    ← OpenAPI 3.0 YAML per service
├── wireframes/
├── domain-model/
└── docs/
```

## Architecture Decision Records

IMPORTANT: Always read the relevant ADR before generating artifacts that touch these areas.

| ADR | Decision | When to Read |
|---|---|---|
| ADR-001 | PostgreSQL 16 + PostGIS + TimescaleDB + pgvector | Any database-related task |
| ADR-002 | Spring Boot (M1/M2/M4) + Quarkus (M3/M5/M6) | Generating OpenAPI specs, service scaffolds |
| ADR-003 | Apache Kafka + Avro + Schema Registry | Event schemas, topic definitions |
| ADR-004 | Angular 18 for web dashboard | Frontend-related design artifacts |
| ADR-005 | Kotlin Multiplatform for mobile | Mobile-related design artifacts |
| ADR-006 | Modular pluggable repos + shared database | Anything about repo structure, CI/CD, module boundaries |

## Module Details

| # | Module | Framework | Flyway Prefix | DDL Path |
|---|---|---|---|---|
| M1 | Plantation Field Records | Spring Boot | V1_xxx | `database/module-1-field-records/plantation_field_records_ddl.sql` |
| M2 | Tree Records & Tracking | Spring Boot | V2_xxx | `database/module-2-tree-records/tree_records_tracking_ddl.sql` |
| M3 | Tapping Task Monitoring | Quarkus | V3_xxx | `database/module-3-tapping-task/tapping_task_monitoring_ddl.sql` |
| M4 | Workforce Management | Spring Boot | V4_xxx | `database/module-4-workforce/workforce_management_ddl.sql` |
| M5 | Daily Activity Monitoring | Quarkus | V5_xxx | `database/module-5-daily-activity/daily_activity_monitoring_ddl.sql` |
| M6 | Attendance Management | Quarkus | V6_xxx | `database/module-6-attendance/attendance_management_ddl.sql` |

Shared platform objects (extensions, 39 lookups, 25 cross-module views, cross-module triggers) use prefix **V0_xxx** and are owned by `rpms-platform`.

## Module Dependency Order

Always work in this order: **M1 → M2 → M4 → M3 → M5 → M6**

```
M1 (Plantation) ← foundation, no dependencies
├── M2 (Tree) ← depends on M1 (field, plantation, clone)
├── M4 (Workforce) ← depends on M1 (plantation, division, field)
│   ├── M3 (Tapping) ← depends on M1, M2, M4 (field, tree, worker)
│   ├── M5 (Activity) ← depends on M1, M3, M4 (field, tapping_task, worker)
│   └── M6 (Attendance) ← depends on M1, M3, M4, M5 (worker, activity, iot_device)
```

## Database Conventions

All spatial columns use **SRID 4326 (WGS 84)**. GPS point is auto-generated from lat/lon via triggers.

Immutable tables (never UPDATE/DELETE): `attendance_scan_log`, `tree_status_change_log`, `worker_status_change_log`

Auto-calculated fields (via triggers, not application code):
- `daily_attendance.work_hours`, `late_minutes`, `overtime_minutes`
- `tapping_task.completion_pct`
- `latex_collection_record.dry_rubber_kg` (net_weight × DRC / 100)
- `gang.current_member_count`
- `worker_leave_balance.remaining_days` (GENERATED column)
- `worker.full_name` (GENERATED column)

`iot_sensor_reading` is a TimescaleDB hypertable partitioned monthly. Always include time range predicates.

## Kafka Event Catalog

Topic naming: `rpms.{module}.{event-name}` (e.g., `rpms.tapping.task-completed`)

Schema evolution: BACKWARD compatibility mode in Schema Registry. Add optional fields with defaults. Never remove or rename fields. Breaking changes create a new topic version (e.g., `rpms.tapping.task-completed.v2`).

| Event | Producer Module | Key Consumers | Partition Key |
|---|---|---|---|
| PlantationCreated | M1 | reporting | plantation_id |
| FieldStatusChanged | M1 | M3, M5 | field_id |
| TreeStatusChanged | M2 | M3, reporting | field_id |
| DiseaseIncidentDetected | M2 | notification, M5 | field_id |
| TappingTaskCompleted | M3 | M5, reporting, notification | field_id |
| LatexCollected | M3 | reporting | field_id |
| QualityTestFailed | M3 | notification | collection_id |
| WorkerStatusChanged | M4 | M3, M5, M6 | worker_id |
| LeaveApproved | M4 | M6 | worker_id |
| ActivityCompleted | M5 | reporting | field_id |
| InspectionFailed | M5 | notification | field_id |
| AttendanceScanReceived | M6 | anomaly-detection | worker_id |
| DailyAttendanceFinalized | M6 | reporting | plantation_id |

---

## Rules for Generating Artifacts

### OpenAPI Specs (output to `api-contracts/`)

Read the DDL first, then apply these rules:

- Geometry columns → expose as `latitude: number` + `longitude: number` in DTOs, never raw WKT/GeoJSON
- JSONB columns (`ai_analysis_result`, etc.) → type as `object` with `additionalProperties: true`, mark `readOnly: true`
- Lookup FK columns → expose as the VARCHAR natural key code (e.g., `tappingSystem: "S/2 d2"` not `tappingSystemId: 7`)
- Immutable tables → GET and POST only (no PUT, DELETE, PATCH)
- All list endpoints → page/size/sort query params, response wrapped in `{ content: [], totalElements, totalPages, page, size }`
- Security → all endpoints require `BearerAuth` (Keycloak JWT)
- Timestamps → `created_at`, `updated_at` are `readOnly: true`
- Spatial filtering → add optional `lat`, `lon`, `radiusKm` query params where applicable
- Naming → camelCase for properties, kebab-case for paths (e.g., `/api/tapping/tapping-tasks/{taskId}`)
- File naming → `{module}-service-openapi.yaml`

### Avro Event Schemas (output to `api-contracts/events/`)

- Namespace: `com.rpms.events.{module}` (e.g., `com.rpms.events.tapping`)
- Include `EventMetadata` record: `eventId` (UUID string), `timestamp` (ISO instant string), `source` (service name), `correlationId`
- Use logical types: `timestamp-millis` for instants, `uuid` for UUIDs
- All fields that reference cross-module entities use the ID only (e.g., `workerId: int`, not a nested worker object)
- File naming: `{EventName}.avsc` (PascalCase, e.g., `TappingTaskCompleted.avsc`)

### Flyway Migrations (output to `database/migrations/`)

Split each module DDL into versioned scripts with the module prefix:

| Version | Content |
|---|---|
| `V{N}_001__create_{module}_tables.sql` | CREATE TABLE statements only |
| `V{N}_002__create_{module}_indexes.sql` | CREATE INDEX statements |
| `V{N}_003__create_{module}_views.sql` | CREATE VIEW statements |
| `V{N}_004__create_{module}_triggers.sql` | CREATE FUNCTION + CREATE TRIGGER |
| `V{N}_005__seed_{module}_lookups.sql` | INSERT INTO lu_* statements |

Where N = module number (0 for platform, 1-6 for modules).

### ADRs (output to `architecture/architecture-decisions/`)

Follow the existing format. Read any existing ADR for reference. Key rules:
- Never modify an accepted ADR — create a new ADR that supersedes it
- Number sequentially: `ADR-007-*.md`, `ADR-008-*.md`, etc.
- Include: Date, Status, Deciders, Context, Decision Drivers, Considered Options (with pros/cons), Decision Outcome, Consequences, Risks

### Wireframes / Domain Models / Docs

- Wireframes → `wireframes/` (Mermaid, HTML, or reference to Figma)
- Domain model → `domain-model/` (bounded contexts, event storming, glossary)
- Technical docs → `docs/` (NFRs, security architecture, data flow diagrams)

---

## NEVER Do in This Repo

- NEVER create Java, Kotlin, TypeScript, Python, or any application source files
- NEVER modify existing DDL files — they are finalized schemas; corrections go via Flyway migrations
- NEVER modify accepted ADRs — create a new superseding ADR instead
- NEVER generate pom.xml, build.gradle, package.json, Dockerfile, or CI/CD workflow files
- NEVER delete existing artifacts

## Technology Stack Quick Reference

See @RPMS_PROJECT_CONTEXT.md for the full technology stack table. Key facts:

- Database: PostgreSQL 16 + PostGIS 3.4 + TimescaleDB + pgvector
- Backend: Java 21 + Spring Boot 3 (CRUD) / Quarkus 3 (high-throughput)
- Mobile: Kotlin Multiplatform + Jetpack Compose + Ktor + SQLDelight
- Web: Angular 18 + ngx-charts + ngx-mapbox-gl + RxJS
- Events: Apache Kafka + Confluent Schema Registry (Avro)
- Gateway: Spring Cloud Gateway + Keycloak (OAuth2/OIDC)
- Shared libs: rpms-common (DTOs), rpms-security (JWT), rpms-spatial (PostGIS)

## Current Status

| Area | Status |
|---|---|
| Database schema — all 6 modules | ✅ Complete (60 tables + 39 lookups + 25 views + 30 triggers) |
| Architecture diagrams | ✅ Complete (updated for modular architecture) |
| ADRs (ADR-001 through ADR-006) | ✅ Complete |
| Modular architecture implementation guide | ✅ Complete |
| API contracts (OpenAPI YAML) | 🔲 Not started |
| Avro event schemas | 🔲 Not started |
| Flyway migration scripts | 🔲 Not started |
| Keycloak realm + role matrix | 🔲 Not started |
| Wireframes / UI mockups | 🔲 Not started |
| Domain model / bounded contexts | 🔲 Not started |

**Next tasks (in priority order):**
1. API contracts — OpenAPI 3.0 specs per module service (start with M1)
2. Avro event schemas — all Kafka domain events from the catalog above
3. Flyway migrations — convert DDLs to prefixed migration scripts (V0 platform, then V1-V6 modules)
4. Keycloak realm design — roles, permissions, realm config
