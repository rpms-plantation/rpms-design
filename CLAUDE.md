# CLAUDE.md — rpms-design

> **Read this file at the start of every Claude Code session in this repository.**
> This file gives Claude Code full context about the RPMS project, what this repo contains,
> how to navigate it, and the rules for working with it.

---

## What This Repository Is

`rpms-design` is the **read-only source of truth** for all RPMS design artifacts. It contains
database schemas, architecture diagrams, Architecture Decision Records (ADRs), and API contracts.

**This repo is NEVER the implementation target.** Claude Code must never generate or modify
application source code here. When generating code, output it to `rpms-backend` or `rpms-mobile`.

The two implementation repos treat this repo as their upstream reference:
- `rpms-backend` — reads DDLs and OpenAPI specs from here to generate service code
- `rpms-mobile` — reads OpenAPI specs from here to generate Ktor clients and Angular services

---

## Project Overview

**RPMS** (Rubber Plantation Management System) is an enterprise platform for managing rubber
plantation operations end-to-end — from field records and individual tree tracking through daily
tapping operations to workforce management and attendance.

### Phase 1 — Six Core Modules (Database Design: COMPLETE)

| # | Module | DDL File | Service | Framework |
|---|---|---|---|---|
| M1 | Plantation Field Records | `plantation_field_records_ddl.sql` | `plantation-service` | Spring Boot 3 |
| M2 | Tree Records & Tracking | `tree_records_tracking_ddl.sql` | `tree-service` | Spring Boot 3 |
| M3 | Tapping Task Monitoring | `tapping_task_monitoring_ddl.sql` | `tapping-service` | Quarkus 3 |
| M4 | Workforce Management | `workforce_management_ddl.sql` | `workforce-service` | Spring Boot 3 |
| M5 | Daily Activity Monitoring | `daily_activity_monitoring_ddl.sql` | `activity-service` | Quarkus 3 |
| M6 | Attendance Management | `attendance_management_ddl.sql` | `attendance-service` | Quarkus 3 |

**Framework split rationale:** Spring Boot for stable CRUD (M1, M2, M4). Quarkus for
high-throughput burst services (M3, M5, M6) — fast startup, low memory, reactive Kafka.
See `architecture/architecture-decisions/ADR-002-spring-vs-quarkus.md` for full reasoning.

### Database Stats (All Modules Combined)

| Artifact | Count |
|---|---|
| Core / analytics tables | 60 |
| Lookup tables (pre-seeded) | 39 |
| Views | 25 |
| Triggers | 30 |

Database engine: **PostgreSQL 16 + PostGIS 3.4 + TimescaleDB + pgvector**

---

## Repository Structure

```
rpms-design/
│
├── CLAUDE.md                                ← THIS FILE
├── README.md                                ← Human-readable project index
├── RPMS_PROJECT_CONTEXT.md                  ← Session continuity document (paste into new sessions)
│
├── architecture/
│   ├── rpms_high_level_architecture.html    ← Interactive 4-tab architecture diagram (open in browser)
│   ├── rpms_artifact_storage_strategy.html  ← Storage strategy & 3-repo structure
│   ├── deployment-topology.mermaid
│   └── architecture-decisions/
│       ├── ADR-001-database-choice.md       ← PostgreSQL + PostGIS + TimescaleDB
│       ├── ADR-002-spring-vs-quarkus.md     ← Framework split decision
│       ├── ADR-003-event-backbone.md        ← Kafka + Avro + Schema Registry
│       ├── ADR-004-angular-over-react.md    ← Web dashboard framework
│       └── ADR-005-kmp-over-flutter.md      ← Mobile framework
│
├── database/
│   ├── module-1-field-records/
│   │   ├── plantation_field_records_ddl.sql
│   │   ├── plantation_db_design_diagrams.html
│   │   ├── plantation_er_diagram.mermaid
│   │   └── README.md
│   ├── module-2-tree-records/
│   │   ├── tree_records_tracking_ddl.sql
│   │   ├── tree_records_tracking_diagrams.html
│   │   ├── tree_records_tracking_er.mermaid
│   │   └── README.md
│   ├── module-3-tapping-task/
│   │   ├── tapping_task_monitoring_ddl.sql
│   │   ├── tapping_task_monitoring_diagrams.html
│   │   ├── tapping_task_monitoring_er.mermaid
│   │   └── README.md
│   ├── module-4-workforce/
│   │   ├── workforce_management_ddl.sql
│   │   ├── workforce_management_diagrams.html
│   │   ├── workforce_management_er.mermaid
│   │   └── README.md
│   ├── module-5-daily-activity/
│   │   ├── daily_activity_monitoring_ddl.sql
│   │   ├── daily_activity_monitoring_diagrams.html
│   │   ├── daily_activity_monitoring_er.mermaid
│   │   └── README.md
│   ├── module-6-attendance/
│   │   ├── attendance_management_ddl.sql
│   │   ├── attendance_management_diagrams.html
│   │   ├── attendance_management_er.mermaid
│   │   └── README.md
│   ├── migrations/                          ← Flyway scripts (to be generated from DDLs)
│   └── seed-data/                           ← Lookup INSERT scripts (also inside each DDL)
│
├── api-contracts/                           ← OpenAPI 3.0 YAML specs per service
│   ├── plantation-service-openapi.yaml
│   ├── tree-service-openapi.yaml
│   ├── tapping-service-openapi.yaml
│   ├── workforce-service-openapi.yaml
│   ├── activity-service-openapi.yaml
│   └── attendance-service-openapi.yaml
│
├── kafka/
│   ├── event-catalog.yaml                   ← All Kafka events: topic, producer, consumers, key
│   └── avro-schemas/                        ← .avsc files per event
│
├── wireframes/
│   ├── mobile-tapper-app/
│   ├── supervisor-tablet/
│   └── management-dashboard/
│
├── domain-model/
│   ├── bounded-contexts.mermaid
│   ├── event-storming-results.md
│   └── domain-glossary.md
│
└── docs/
    ├── non-functional-requirements.md
    ├── security-architecture.md
    └── data-flow-diagrams.md
```

---

## Module-by-Module Database Reference

### M1 — Plantation Field Records
**DDL:** `database/module-1-field-records/plantation_field_records_ddl.sql`

Core tables: `plantation`, `division`, `field`, `nursery`, `nursery_clone_distribution`,
`plantation_land_use`, `clone_master`, `field_lifecycle_history`, `annual_area_snapshot`

Lookups: `lu_measurement_unit`, `lu_land_use_type`, `lu_nursery_type`, `lu_field_category`,
`lu_tapping_system`

Views: `vw_plantation_area_summary`, `vw_clone_distribution_summary`,
`vw_nursery_clone_summary`, `vw_immature_fields`, `vw_mature_fields`

Spatial: PostGIS `Polygon` on `plantation.boundary`, `field.boundary`, `nursery.boundary`

Key relationships: plantation → division → field; field → clone_master (clone planted in field)

---

### M2 — Tree Records & Tracking
**DDL:** `database/module-2-tree-records/tree_records_tracking_ddl.sql`

Core tables: `tree` (BIGSERIAL PK — millions of rows), `tree_row`, `tree_growth_measurement`,
`tree_panel_history`, `tree_census_summary`

IoT: `tree_tag` (NFC / RFID / QR / BLE)

Health: `tree_health_inspection`, `tree_disease_incident`, `tree_treatment_record`,
`tree_mortality_record`

Audit: `tree_status_change_log` — has `blockchain_tx_hash` (immutable status audit trail)

Lookups: `lu_tree_status`, `lu_health_rating`, `disease_master`, `lu_treatment_type`,
`lu_growth_parameter`, `lu_tag_type`, `lu_mortality_cause`

Views: `vw_tree_profile`, `vw_field_tree_summary`, `vw_disease_hotspot`, `vw_mortality_analysis`

Triggers: auto-log status changes → `tree_status_change_log`; sync `current_girth_cm` from
latest measurement; GPS `Point` auto-generated from `gps_latitude`/`gps_longitude`; increment
`tree_tag.scan_count` on scan

Spatial: PostGIS `Point` on `tree.gps_point` (SRID 4326)

Cross-module FK: `tree.plantation_id` → M1 `plantation`; `tree.field_id` → M1 `field`;
`tree.clone_id` → M1 `clone_master`

---

### M3 — Tapping Task Monitoring
**DDL:** `database/module-3-tapping-task/tapping_task_monitoring_ddl.sql`

Core tables: `tapping_schedule`, `tapping_task` (central hub), `tapping_task_tree_detail`
(NFC scan per tree), `latex_collection_record`, `collection_point`, `weather_observation`

Quality: `latex_quality_test` — DRC%, ammonia, pH, VFA testing; `is_within_spec` flag

IoT: `iot_device`, `iot_sensor_reading` (TimescaleDB hypertable, range-partitioned by month)

Lookups: `lu_tapping_task_status`, `lu_collection_method`, `lu_weather_condition`,
`lu_iot_device_type`, `lu_iot_sensor_type`, `lu_latex_grade`

Views: `vw_daily_yield_summary`, `vw_tapper_performance`, `vw_field_yield_analytics`,
`vw_quality_alerts`

Triggers: auto-calculate `yield_per_tree`, `dry_rubber_kg` from DRC%; auto-update
`tapping_task.completion_pct`; `blockchain_tx_hash` on `latex_collection_record` (yield provenance)

AI fields: `tapping_task_tree_detail.ai_cut_quality_score` (JSONB), `ai_anomaly_flag`

Special: `iot_sensor_reading` is a **TimescaleDB hypertable** — never query without a time
range filter; always use `WHERE reading_time BETWEEN x AND y`

---

### M4 — Workforce Management
**DDL:** `database/module-4-workforce/workforce_management_ddl.sql`

Core tables: `worker` (generated column `full_name`), `worker_skill`, `worker_certification`,
`gang`, `gang_member`, `worker_leave_entitlement`, `worker_leave_balance`
(generated column `remaining_days`), `leave_application`, `training_program`,
`worker_training_record`, `safety_incident`, `pay_structure`

Lookups: `lu_worker_status`, `lu_employment_type`, `lu_skill_type`, `lu_certification_type`,
`lu_gang_type`, `lu_leave_type`, `lu_leave_status`, `lu_training_type`,
`lu_incident_severity`, `lu_pay_component`

Views: `vw_worker_profile`, `vw_gang_composition`, `vw_leave_balance_summary`,
`vw_workforce_analytics`

Cross-module FK: `worker.plantation_id` → M1 `plantation`; `gang.field_id` → M1 `field`

---

### M5 — Daily Activity Monitoring
**DDL:** `database/module-5-daily-activity/daily_activity_monitoring_ddl.sql`

Core tables: `activity_type`, `daily_activity` (central hub), `activity_material_usage`,
`activity_photo`, `field_inspection`, `inspection_finding`, `activity_assignment`,
`activity_progress_log`, `weather_daily`

Lookups: `lu_activity_status`, `lu_activity_category`, `lu_material_type`,
`lu_inspection_type`, `lu_finding_severity`

Views: `vw_daily_activity_summary`, `vw_field_inspection_alerts`,
`vw_material_consumption`, `vw_activity_performance`

AI fields: `activity_photo.ai_analysis_result` (JSONB), `ai_analysis_status`,
`daily_activity.ai_efficiency_score`

GPS: `daily_activity.gps_route` — PostGIS `LineString` (continuous GPS track of worker movement)

---

### M6 — Attendance Management
**DDL:** `database/module-6-attendance/attendance_management_ddl.sql`

Core tables: `attendance_shift`, `attendance_roster`, `scan_log` (**IMMUTABLE** — raw scan
events, never updated), `daily_attendance` (derived, recalculated from `scan_log`),
`attendance_regularization`, `overtime_record`, `monthly_attendance_summary`

Lookups: `lu_scan_method`, `lu_attendance_status`, `lu_absent_reason`,
`lu_overtime_type`, `lu_regularization_reason`

Views: `vw_daily_attendance_report`, `vw_monthly_payroll_summary`,
`vw_attendance_analytics`, `vw_late_overtime_summary`

**Two-tier architecture (CRITICAL):**
1. `scan_log` — append-only, immutable raw scan events (biometric, NFC badge, GPS geofence,
   mobile app). Never update or delete rows here.
2. `daily_attendance` — derived record, recalculated by trigger whenever a new scan is added
   to `scan_log`. Stores computed: work hours, late minutes, OT minutes, attendance status.

`blockchain_tx_hash` on `daily_attendance` (tamper-proof payroll record)

Multi-method check-in: BIOMETRIC, NFC_BADGE, GPS_GEOFENCE, MOBILE_APP — each has a
`reliability_score` used to resolve conflicts when multiple methods fire for same worker.

---

## Critical Database Design Rules

These rules are derived from the DDLs and must be respected in ALL generated code.

### Spatial / PostGIS
- **All spatial columns use SRID 4326 (WGS 84)** — always specify `ST_SetSRID(..., 4326)`
- Never store raw geometry from the client — always transform via `ST_GeomFromGeoJSON` or
  `ST_GeomFromText` with explicit SRID
- GPS `Point` columns on `tree` and `worker` check-in are **auto-generated by triggers** from
  `gps_latitude` / `gps_longitude` — never insert the point column directly
- Field / plantation boundaries are `Polygon`; GPS worker routes are `LineString`;
  tree positions and check-in points are `Point`
- All spatial queries must use PostGIS operators (`ST_Within`, `ST_Intersects`, `ST_Distance`,
  etc.) — never calculate distances or containment in application code

### Immutability
- `scan_log` is **append-only** — no UPDATE or DELETE ever. Corrections go through
  `attendance_regularization`
- `tree_status_change_log` is **append-only** — status changes are logged, not modified
- `blockchain_tx_hash` columns mark records that have been anchored to Hyperledger Fabric —
  treat as immutable once the hash is set

### AI / ML Fields
- `ai_analysis_result` columns are **JSONB** — schema is intentionally flexible and will evolve
- `ai_anomaly_flag` is a `BOOLEAN` — set by the AI/ML service via async update after analysis
- `ai_efficiency_score` / `ai_cut_quality_score` are `NUMERIC` — populated asynchronously,
  may be NULL until the AI service processes the record

### Lookup Tables
- All 39 lookup tables are **pre-seeded** with rubber plantation domain data in the DDL
- Lookup table naming pattern: `lu_<domain>` (e.g., `lu_tapping_system`, `lu_tree_status`)
- Lookup PKs are typically `VARCHAR` natural keys (e.g., `status_code = 'ACTIVE'`), not
  surrogate integers — reference them by code, not ID

### Triggers (Auto-computed Fields)
These fields are **maintained by database triggers** — never compute them in application code:
- `worker.full_name` — generated column from `first_name` + `last_name`
- `worker_leave_balance.remaining_days` — generated column
- `tree.current_girth_cm` — synced from latest `tree_growth_measurement`
- `daily_attendance.work_hours`, `late_minutes`, `overtime_minutes` — computed from `scan_log`
- `tapping_task.completion_pct` — computed from `tapping_task_tree_detail` counts
- `latex_collection_record.dry_rubber_kg` — computed from `net_weight_kg × drc_pct / 100`
- `gang.current_member_count` — maintained by trigger on `gang_member` insert/delete

### TimescaleDB
- `iot_sensor_reading` is a **TimescaleDB hypertable** partitioned by `reading_time` (monthly)
- Always include a time range predicate when querying this table:
  `WHERE reading_time BETWEEN :start AND :end`
- Never do full-table scans on `iot_sensor_reading`

---

## Technology Stack Reference

| Layer | Technology | Version |
|---|---|---|
| Backend (CRUD) | Java + Spring Boot | 21 LTS + 3.x |
| Backend (high-throughput) | Java + Quarkus | 21 LTS + 3.x |
| Integration | Apache Camel | 4.x |
| Event Backbone | Apache Kafka + Avro | 3.x + Schema Registry |
| CDC | Debezium | Latest stable |
| Mobile | Kotlin Multiplatform + Jetpack Compose | KMP 2.1 |
| Mobile Networking | Ktor | 3.x |
| Mobile Offline DB | SQLDelight | 2.x |
| Web Dashboard | Angular | 18 |
| API Gateway | Spring Cloud Gateway + Keycloak | Latest + 24.x |
| Database | PostgreSQL + PostGIS + TimescaleDB + pgvector | 16 + 3.4 |
| Cache | Redis | 7 |
| Search | Elasticsearch | 8 |
| Object Storage | MinIO / S3 | — |
| AI/ML | Python + FastAPI + PyTorch + LangChain | 3.12 |
| Workflow Orchestration | Temporal.io | Latest stable |
| Blockchain | Hyperledger Fabric | 2.x (private) |
| Observability | OpenTelemetry + Grafana + Prometheus | — |
| CI/CD | GitHub Actions + ArgoCD + Terraform | — |
| Kubernetes (cloud) | EKS / GKE | — |
| Kubernetes (edge) | K3s + Eclipse Mosquitto MQTT | — |

---

## Architecture Decision Records (ADRs)

Always read the relevant ADR before generating code that touches these areas:

| ADR | Decision | File |
|---|---|---|
| ADR-001 | PostgreSQL + PostGIS + TimescaleDB as primary DB | `architecture/architecture-decisions/ADR-001-database-choice.md` |
| ADR-002 | Spring Boot (M1/M2/M4) vs Quarkus (M3/M5/M6) | `architecture/architecture-decisions/ADR-002-spring-vs-quarkus.md` |
| ADR-003 | Apache Kafka + Avro + Schema Registry as event backbone | `architecture/architecture-decisions/ADR-003-event-backbone.md` |
| ADR-004 | Angular 18 over React for web dashboard | `architecture/architecture-decisions/ADR-004-angular-over-react.md` |
| ADR-005 | Kotlin Multiplatform over Flutter for mobile | `architecture/architecture-decisions/ADR-005-kmp-over-flutter.md` |

---

## Kafka Event Catalog (Phase 1)

These events flow across module boundaries. The full catalog is in `kafka/event-catalog.yaml`
once generated. Avro schemas go in `kafka/avro-schemas/`.

| Event | Producer | Consumer(s) | Partition Key |
|---|---|---|---|
| `PlantationCreated` | plantation-service | reporting-service | `plantation_id` |
| `FieldStatusChanged` | plantation-service | tapping-service, activity-service | `field_id` |
| `TreeStatusChanged` | tree-service | tapping-service, reporting-service | `field_id` |
| `DiseaseIncidentDetected` | tree-service | notification-service, activity-service | `field_id` |
| `TappingTaskCompleted` | tapping-service | activity-service, reporting-service, notification-service | `field_id` |
| `LatexCollected` | tapping-service | reporting-service, (future) financial-service | `field_id` |
| `QualityTestFailed` | tapping-service | notification-service | `collection_id` |
| `WorkerStatusChanged` | workforce-service | tapping-service, activity-service, attendance-service | `worker_id` |
| `AttendanceScanReceived` | attendance-service | notification-service | `worker_id` |
| `DailyAttendanceFinalized` | attendance-service | reporting-service, (future) payroll-service | `plantation_id` |
| `ActivityCompleted` | activity-service | reporting-service | `field_id` |
| `InspectionFindingCritical` | activity-service | notification-service | `field_id` |

Topic naming convention: `rpms.<module>.<entity>.<event>` (e.g., `rpms.tapping.task.completed`)

---

## Module Dependency Chain

```
M1 (Plantation Field Records)
  └── M2 (Tree Records)         ← tree belongs to field, plantation, clone
        └── M3 (Tapping Task)   ← task assigned to field, tree, tapper (worker)
M1 + M4 (Workforce)
        └── M5 (Daily Activity) ← activity in field, performed by worker
M4 + M5 (Attendance)
        └── M6 (Attendance)     ← scan_log → daily_attendance for worker at plantation
```

Always develop and test in dependency order: M1 → M2 → M4 → M3 → M5 → M6.

---

## How Claude Code Should Use This Repo

### Reading artifacts for code generation (✅ DO)

```
# Generate OpenAPI spec from DDL
Read database/module-1-field-records/plantation_field_records_ddl.sql
→ Generate api-contracts/plantation-service-openapi.yaml

# Scaffold a service from DDL + OpenAPI
Read database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
Read api-contracts/tapping-service-openapi.yaml
→ Generate service scaffold in rpms-backend/services/tapping-service/

# Generate Flyway migrations from DDL
Read database/module-2-tree-records/tree_records_tracking_ddl.sql
→ Generate database/migrations/V2.1__tree_tables.sql etc.

# Generate Avro schemas from event catalog
Read kafka/event-catalog.yaml
→ Generate kafka/avro-schemas/TappingTaskCompleted.avsc etc.
```

### Never do in this repo (❌ DON'T)

- Never create Java, Kotlin, TypeScript, or Python application source files here
- Never modify DDL files — they are the finalized schema. Corrections go via new Flyway migrations
- Never modify ADR files once accepted — append a new ADR instead
- Never generate test files, build files (pom.xml, build.gradle), or Docker configs here
- Never delete existing artifacts

---

## Generating Flyway Migrations from DDL

When converting a DDL file into Flyway migrations, split it into these versioned scripts:

| Version | Content | Example |
|---|---|---|
| `V{M}.1__create_{module}_tables.sql` | CREATE TABLE statements only | `V1.1__create_plantation_tables.sql` |
| `V{M}.2__create_{module}_indexes.sql` | CREATE INDEX statements | `V1.2__create_plantation_indexes.sql` |
| `V{M}.3__create_{module}_views.sql` | CREATE VIEW statements | `V1.3__create_plantation_views.sql` |
| `V{M}.4__create_{module}_triggers.sql` | CREATE FUNCTION + CREATE TRIGGER | `V1.4__create_plantation_triggers.sql` |
| `V{M}.5__seed_{module}_lookups.sql` | INSERT INTO lu_* statements | `V1.5__seed_plantation_lookups.sql` |

Output path: `database/migrations/`

---

## Generating OpenAPI Specs from DDL

When generating an OpenAPI 3.0 YAML spec from a DDL file, follow these rules:

- **Geometry columns** — expose as `latitude: number` + `longitude: number` pairs in DTOs,
  never as raw WKT or GeoJSON geometry strings in REST requests
- **JSONB columns** (`ai_analysis_result`, etc.) — type as `object` with
  `additionalProperties: true` and mark as `readOnly: true` (set by AI service, not client)
- **Lookup FK columns** — expose as the natural key `VARCHAR` code
  (e.g., `tappingSystem: string`, not `tappingSystemId: integer`)
- **Immutable tables** (`scan_log`, `tree_status_change_log`) — expose only GET and POST
  (no PUT, no DELETE, no PATCH)
- **Pagination** — all list endpoints use cursor-based pagination:
  `page`, `size`, `sort` query params; response wraps in `{ content: [], totalElements, totalPages }`
- **Security** — all endpoints require `BearerAuth` (Keycloak JWT). Add
  `securitySchemes.BearerAuth` globally
- **Timestamps** — all `created_at`, `updated_at` fields are `readOnly: true`
- **Spatial filter params** — add optional query params `boundaryWkt`, `lat`, `lon`, `radiusKm`
  for endpoints that support spatial filtering (field list, tree list, worker list)

---

## Session Startup Checklist

At the start of a Claude Code session in this repo, do the following:

1. Read this `CLAUDE.md` file completely
2. Identify which module(s) the session will work on
3. Read the DDL for that module: `database/module-N-*/[module]_ddl.sql`
4. Read the relevant ADR(s) if the task involves framework, database, or event design
5. Check `api-contracts/` to see if an OpenAPI spec already exists for the module
6. Check `kafka/event-catalog.yaml` for event definitions if the task involves Kafka

---

## Related Repositories

| Repository | Purpose | Branch Strategy |
|---|---|---|
| `rpms-design` (this repo) | Design artifacts — DDL, diagrams, ADRs, API contracts | `main` only — squash merge |
| `rpms-backend` | Java/Quarkus microservices + Python AI services | `main` + `feature/*` branches |
| `rpms-mobile` | KMP Android app + Angular web dashboard | `main` + `feature/*` branches |

---

## Current Development Status

| Area | Status |
|---|---|
| Database schema — all 6 modules | ✅ Complete |
| Architecture diagrams | ✅ Complete |
| Architecture Decision Records (ADRs) | ✅ Complete |
| API contracts (OpenAPI YAML) | 🔲 Not started |
| Kafka event catalog + Avro schemas | 🔲 Not started |
| Flyway migration scripts | 🔲 Not started |
| Domain model / bounded contexts | 🔲 Not started |
| Keycloak realm + role matrix | 🔲 Not started |
| Wireframes / UI mockups | 🔲 Not started |
| Non-functional requirements doc | 🔲 Not started |
| Security architecture doc | 🔲 Not started |

**Next recommended tasks:**
1. Generate OpenAPI 3.0 specs for all 6 services (start with `plantation-service`, then `tree-service`)
2. Generate Kafka event catalog YAML and Avro schemas
3. Convert DDLs to Flyway migration scripts
