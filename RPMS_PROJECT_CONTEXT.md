# RPMS — Rubber Plantation Management System
## Project Context Document (paste this at the start of new Claude sessions)

---

## Project Overview
We are designing and building a **Rubber Plantation Management System (RPMS)** — a comprehensive enterprise platform for managing rubber plantation operations. The system covers field records, individual tree tracking, tapping operations, workforce, daily activities, and attendance — integrated with IoT, Blockchain, Gen AI, AR/MR, and mobile technologies.

The system uses a **modular pluggable architecture** — each business module lives in its own repository as a full vertical slice (backend service + Angular library + KMP mobile feature + Flyway migrations + CI/CD pipeline), all sharing a single PostgreSQL database. Thin shell applications lazy-load module packages at runtime.

---

## Modular Pluggable Architecture (ADR-006)

### Core Principles
- **One repo per module** — full vertical slice, independent CI/CD, independent release cycle
- **Shared database** — all 60 tables, 39 lookups, 25 views, 30 triggers intact with full referential integrity
- **Single writer, many readers** — each table has exactly one module that writes to it; any module can read from any table (enforced via PostgreSQL permissions)
- **Platform foundation** — shared Java libraries, Avro event schemas, Angular/KMP packages published as versioned artifacts from `rpms-platform`
- **Thin shell compositors** — `rpms-shell-web` (Angular) and `rpms-shell-mobile` (Compose) contain zero business logic; they compose module packages via lazy loading
- **Plugin model** — adding a Phase 2 module = 1 route + 1 nav entry + 1 dependency in each shell; zero changes to existing modules

### Repository Map (10 Repositories)
```
rpms-plantation (GitHub Organization)
│
├── rpms-design                 ← Design artifacts, DDL, diagrams, ADRs, API contracts
│
├── rpms-platform               ← Shared libs, event schemas, API gateway, cross-cutting services, infra
│
├── rpms-mod-plantation         ← M1: Spring Boot backend + Angular lib + KMP feature + Flyway V1_xxx
├── rpms-mod-tree               ← M2: Spring Boot backend + Angular lib + KMP feature + Flyway V2_xxx
├── rpms-mod-tapping            ← M3: Quarkus backend + Angular lib + KMP feature + Flyway V3_xxx
├── rpms-mod-workforce          ← M4: Spring Boot backend + Angular lib + KMP feature + Flyway V4_xxx
├── rpms-mod-activity           ← M5: Quarkus backend + Angular lib + KMP feature + Flyway V5_xxx
├── rpms-mod-attendance         ← M6: Quarkus backend + Angular lib + KMP feature + Flyway V6_xxx
│
├── rpms-shell-web              ← Angular shell: layout, sidebar, routing — lazy-loads @rpms/mod-* libs
└── rpms-shell-mobile          ← Android shell: Compose Navigation host — composes module nav graphs
```

### What Each Module Repo Contains
```
rpms-mod-{module}/
├── backend/              # Spring Boot or Quarkus service
│   ├── src/main/java/    # entity → repository → service → controller → dto → mapper → event
│   └── src/main/resources/db/migration/   # Flyway V{N}_xxx migrations
├── angular-lib/          # Publishable Angular library (@rpms/mod-{module})
│   └── src/lib/          # routes, nav items, providers, pages, components, services
├── kmp-feature/          # Publishable KMP Gradle module (com.rpms:mod-{module}-kmp)
│   ├── commonMain/       # Ktor client, SQLDelight, domain models
│   └── androidMain/      # Compose screens, navigation graph, hardware integration
├── api-contract/         # OpenAPI 3.0 YAML + Avro event schemas
├── k8s/                  # Kubernetes deployment, service, HPA manifests
└── .github/workflows/    # Independent CI/CD pipeline (4 stages)
```

### What rpms-platform Contains
```
rpms-platform/
├── shared-libs/          # Maven artifacts: rpms-common (DTOs, exceptions), rpms-security (Keycloak), rpms-spatial (PostGIS)
├── event-schemas/        # Avro schemas for all Kafka domain events + topic registry
├── api-gateway/          # Spring Cloud Gateway + route config + Keycloak realm
├── services/             # Cross-cutting: notification-service, reporting-service
├── database/migrations/  # V0_xxx: extensions, 39 lookups, 25 cross-module views, cross-module triggers
├── angular-shared/       # @rpms/shared npm package: map-viewer, data-table, chart-panel, auth, interceptors
├── kmp-shared/           # com.rpms:shared-kmp: base domain models, Ktor client, sync engine
└── infra/                # Terraform, K8s base manifests, docker-compose.dev.yml, edge gateway config
```

### Shell Composition (Plugin Model)

**Angular shell** (`rpms-shell-web`) lazy-loads module packages:
```typescript
// app.routes.ts — one line per module
{ path: 'tapping', loadChildren: () => import('@rpms/mod-tapping').then(m => m.TAPPING_ROUTES) }
```

**Android shell** (`rpms-shell-mobile`) composes module navigation graphs:
```kotlin
// RpmsNavHost.kt — one call per module
NavHost(navController, startDestination = "plantation") {
    plantationNavGraph(navController)
    tappingNavGraph(navController)
    // Adding a module = adding one line here
}
```

### Database Ownership Model

| Module | Framework | Writes To (owns) | Reads From (cross-module) |
|---|---|---|---|
| M1 Plantation | Spring Boot | plantation, division, field, nursery, clone_master, field_lifecycle_history, annual_area_snapshot | — (foundation) |
| M2 Tree | Spring Boot | tree, tree_row, tree_tag, tree_growth_measurement, tree_panel_history, tree_health_inspection, tree_disease_incident, tree_treatment_record, tree_mortality_record, tree_census_summary | plantation, field, clone_master (M1) |
| M3 Tapping | Quarkus | tapping_schedule, tapping_task, tapping_task_tree_detail, latex_collection_record, collection_point, latex_quality_test, weather_observation, iot_device, iot_sensor_reading | field (M1), tree (M2), worker (M4) |
| M4 Workforce | Spring Boot | worker, gang, worker_skill, worker_document, worker_leave, worker_leave_balance, worker_training, worker_pay_structure, worker_safety_incident, worker_status_change_log | plantation, division, field (M1) |
| M5 Activity | Quarkus | daily_work_plan, daily_activity, activity_worker_assignment, activity_material_usage, activity_photo_evidence, supervisor_inspection, inspection_checklist_response, daily_activity_summary | plantation, division, field (M1), worker, gang (M4), tapping_task (M3) |
| M6 Attendance | Quarkus | attendance_scan_log, daily_attendance, shift_roster, overtime_record, attendance_regularization, monthly_attendance_summary | plantation, division (M1), worker, gang, worker_leave (M4), daily_activity (M5), iot_device (M3) |

### Flyway Migration Prefix Convention

| Prefix | Owner | Example |
|---|---|---|
| V0_xxx | rpms-platform | V0_001__extensions.sql, V0_002__shared_lookups.sql, V0_003__cross_module_views.sql |
| V1_xxx | rpms-mod-plantation | V1_001__create_plantation.sql, V1_002__create_field.sql |
| V2_xxx | rpms-mod-tree | V2_001__create_tree.sql, V2_002__create_tree_tag.sql |
| V3_xxx | rpms-mod-tapping | V3_001__create_tapping_task.sql, V3_002__create_latex_collection.sql |
| V4_xxx | rpms-mod-workforce | V4_001__create_worker.sql, V4_002__create_gang.sql |
| V5_xxx | rpms-mod-activity | V5_001__create_daily_work_plan.sql, V5_002__create_daily_activity.sql |
| V6_xxx | rpms-mod-attendance | V6_001__create_scan_log.sql, V6_002__create_daily_attendance.sql |

### CI/CD Per Module (4 stages)
1. **Build + Test** (parallel): Backend (Testcontainers with PG+Kafka), Angular lib (ng build + Jasmine), KMP feature (kotlin.test)
2. **Quality Gates**: OpenAPI lint, Avro schema compatibility check, Flyway validate, Pact contract tests
3. **Publish** (main only): Docker image → GHCR, Angular lib → npm (GitHub Packages), KMP → Maven (GitHub Packages)
4. **Deploy** (main only): Flyway migrate staging DB → ArgoCD sync → webhook triggers shell rebuilds

---

## Phase 1 — Six Core Modules (COMPLETED: Database Design)

### Module 1: Plantation Field Records Management
- **Repo**: `rpms-mod-plantation` (Spring Boot)
- **DDL**: `plantation_field_records_ddl.sql`
- **Flyway prefix**: V1_xxx
- **Tables**: plantation, division, field, nursery, nursery_clone_distribution, plantation_land_use, clone_master, field_lifecycle_history, annual_area_snapshot
- **Lookups**: lu_measurement_unit, lu_land_use_type, lu_nursery_type, lu_field_category, lu_tapping_system
- **Views**: vw_plantation_area_summary, vw_clone_distribution_summary, vw_nursery_clone_summary, vw_immature_fields, vw_mature_fields

### Module 2: Tree Records & Tracking
- **Repo**: `rpms-mod-tree` (Spring Boot)
- **DDL**: `tree_records_tracking_ddl.sql`
- **Flyway prefix**: V2_xxx
- **Core**: tree (BIGSERIAL PK), tree_row, tree_growth_measurement, tree_panel_history, tree_census_summary
- **IoT**: tree_tag (NFC/RFID/QR/BLE)
- **Health**: tree_health_inspection, tree_disease_incident, tree_treatment_record, tree_mortality_record
- **Audit**: tree_status_change_log (with blockchain_tx_hash)
- **Lookups**: lu_tree_status, lu_health_rating, disease_master, lu_treatment_type, lu_growth_parameter, lu_tag_type, lu_mortality_cause
- **Views**: vw_tree_profile, vw_field_tree_summary, vw_disease_hotspot, vw_mortality_analysis
- **Triggers**: Auto-log status changes, sync denormalized girth from measurements, GPS point sync, tag scan counter

### Module 3: Tapping Task Monitoring
- **Repo**: `rpms-mod-tapping` (Quarkus)
- **DDL**: `tapping_task_monitoring_ddl.sql`
- **Flyway prefix**: V3_xxx
- **Core**: tapping_schedule, tapping_task (central hub), tapping_task_tree_detail (NFC per-tree), latex_collection_record, collection_point, weather_observation
- **Quality**: latex_quality_test (DRC, ammonia, pH, VFA testing)
- **IoT**: iot_device, iot_sensor_reading (PARTITIONED by month — TimescaleDB)
- **Analytics**: tapper_performance_daily, field_yield_daily
- **Lookups**: lu_tapping_task_status, lu_latex_grade, lu_tapping_skip_reason, lu_collection_point_type, lu_quality_parameter, lu_iot_device_type
- **Views**: vw_tapping_dashboard_daily, vw_tapper_performance_ranking, vw_clone_yield_analysis, vw_weather_yield_correlation
- **Triggers**: Auto-calc yield_per_tree, auto-calc dry_rubber from DRC, auto-flag out-of-spec quality, GPS sync

### Module 4: Workforce Management
- **Repo**: `rpms-mod-workforce` (Spring Boot)
- **DDL**: `workforce_management_ddl.sql`
- **Flyway prefix**: V4_xxx
- **Core**: worker (SERIAL PK — referenced by tapper_id across M3/M5/M6), gang (teams), worker_skill, worker_field_assignment
- **HR**: worker_next_of_kin, worker_document, worker_leave (approval workflow), worker_leave_balance (auto-calc remaining_days GENERATED column), worker_training (VR/MR/classroom methods)
- **Compensation**: worker_pay_structure (multi-component: basic + piece_rate + incentive + deductions)
- **Safety**: worker_safety_incident
- **Audit**: worker_status_change_log (blockchain_tx_hash)
- **Lookups**: lu_worker_category (15 roles), lu_employment_type, lu_worker_status, lu_skill (16 competencies), lu_proficiency_level, lu_leave_type, lu_relationship_type, lu_document_type, lu_pay_component, lu_training_type
- **Views**: vw_worker_profile, vw_gang_roster, vw_expiring_documents, vw_skill_gap_analysis
- **Key**: worker.reports_to_id self-referencing hierarchy; gang current_size auto-sync via trigger; leave balance auto-update on approval

### Module 5: Daily Activity Monitoring
- **Repo**: `rpms-mod-activity` (Quarkus)
- **DDL**: `daily_activity_monitoring_ddl.sql`
- **Flyway prefix**: V5_xxx
- **Core**: daily_work_plan (container), daily_activity (BIGSERIAL — core entity), activity_worker_assignment (multi-worker)
- **Material**: activity_material_usage, material_master (15 pre-seeded: fertilizers, chemicals, stimulants, fuel)
- **Evidence**: activity_photo_evidence (JSONB ai_analysis_result, geo-tagged)
- **Inspection**: supervisor_inspection (ar_assisted flag, ai_summary), inspection_checklist_response (yes_no / rating_1_5 / numeric / text)
- **Analytics**: daily_activity_summary (AI daily narrative + next-day recommendations)
- **Lookups**: lu_activity_category (15 categories), lu_activity_type (34 specific types), lu_activity_status, lu_activity_priority (with color_hex), lu_inspection_checklist_item
- **Key**: GPS route as GEOMETRY(LineString); JSONB for AI photo analysis; auto-calc completion_pct, man_days, material variance via triggers; plan counts auto-sync

### Module 6: Attendance Management
- **Repo**: `rpms-mod-attendance` (Quarkus)
- **DDL**: `attendance_management_ddl.sql`
- **Flyway prefix**: V6_xxx
- **Core**: daily_attendance (BIGSERIAL — one per worker per day), attendance_scan_log (immutable raw event log)
- **Correction**: attendance_regularization (approval workflow, auto-apply on approval via trigger)
- **Location**: attendance_location (muster points with PostGIS geofence polygons)
- **Roster**: worker_shift_roster (pre-assigned shifts per worker per day)
- **Analytics**: monthly_attendance_summary (payroll-ready: payable_days, OT breakdown, bonus eligibility), plantation_daily_attendance (estate-level snapshot)
- **Lookups**: lu_attendance_status (16 statuses with display_color, is_paid, affects_bonus), lu_checkin_method (8 methods with reliability_score), lu_shift (7 shifts), lu_overtime_type (4 types with multipliers), lu_regularization_reason
- **Key**: Two-tier architecture (scan_log → daily_attendance); auto-calc hours/late/OT via trigger; multi-method check-in with reliability scoring

---

## Technology Stack (FINALIZED)

| Layer | Technology | Purpose |
|---|---|---|
| **Backend (CRUD)** | Java 21 + Spring Boot 3 | Plantation, Tree, Workforce services — stable domain, rich ecosystem |
| **Backend (High-Throughput)** | Java 21 + Quarkus | Tapping, Activity, Attendance services — <1s startup, ~120MB, burst scaling |
| **Platform Libraries** | rpms-common, rpms-security, rpms-spatial | Framework-agnostic shared DTOs, Keycloak JWT, PostGIS helpers |
| **Event Backbone** | Apache Kafka + Confluent Schema Registry (Avro) | Domain events, CDC, IoT telemetry, saga coordination |
| **Integration** | Apache Camel 4 | Edge (MQTT→Kafka) and cloud (external APIs, ERP sync) |
| **Orchestration** | Temporal.io | Saga pattern for cross-module transactions |
| **Mobile** | Kotlin Multiplatform + Jetpack Compose | Android apps (tapper + supervisor), native BLE/NFC/CameraX/GPS |
| **Web Dashboard** | Angular 18 + ngx-charts + ngx-mapbox-gl + RxJS | Management dashboard with real-time streaming, spatial visualization |
| **Shell Compositors** | Angular shell (web) + Compose Navigation shell (Android) | Thin apps that lazy-load module packages — plugin architecture |
| **API Gateway** | Spring Cloud Gateway + Keycloak (OAuth2/OIDC) | Routing, JWT relay, rate limiting, CORS |
| **Database** | PostgreSQL 16 + PostGIS + TimescaleDB + pgvector | Shared database — relational, spatial, time-series, vector search |
| **Cache** | Redis 7 | Tree profile cache, sessions, rate limiting, pub/sub |
| **Search** | Elasticsearch 8 | Full-text search, log aggregation, Kibana dashboards |
| **Object Storage** | MinIO / S3 | Photos, documents, certificates, AI model artifacts |
| **AI/ML** | Python + FastAPI + PyTorch + LangChain + Claude API | Photo analysis, yield prediction, anomaly detection, Gen AI copilot |
| **Blockchain** | Hyperledger Fabric (private) | Yield provenance, attendance anchoring, sustainability certification |
| **Observability** | OpenTelemetry + Grafana + Prometheus + Loki + Tempo | Traces, metrics, logs, distributed tracing |
| **CI/CD** | GitHub Actions + ArgoCD + Terraform | Per-module pipelines, GitOps deployment to Kubernetes |
| **Container Orchestration** | Kubernetes (EKS/GKE) + K3s (edge) | Cloud production + lightweight plantation-edge clusters |

---

## Database Stats Summary
- **60 core/analytics tables** across 6 modules
- **39 lookup tables** (all pre-seeded with rubber plantation data)
- **25 views** (dashboards, analytics, alerts)
- **30 smart triggers** (auto-calc, auto-sync, GPS point, audit logging)
- **PostgreSQL 16 + PostGIS** for spatial, **TimescaleDB** for IoT time-series, **pgvector** for RAG
- **SRID 4326 (WGS 84)** on all spatial columns
- **Single writer per table, many readers** — enforced via PostgreSQL service account permissions

---

## Design Artifacts Created

Each module has 3 artifacts:
1. `.sql` — Complete DDL with tables, indexes, views, triggers, permissions, seed data
2. `.html` — Interactive 4-tab dashboard (ER diagram, table schema cards, relationships table, lifecycle/workflow flow diagram)
3. `.mermaid` — Portable ER diagram for GitHub/Confluence/Notion rendering

Architecture artifacts:
- `rpms_high_level_architecture.html` — 4-tab interactive architecture (diagram with 10-layer modular topology, layer details, tech decisions with ADR references, deployment view)
- `rpms_artifact_storage_strategy.html` — Repository strategy (to be updated for 10-repo structure)
- `modular-architecture-implementation-guide.md` — Full implementation guide: platform repo structure, module template, Angular shell composition, Android shell composition, database ownership, Flyway strategy, CI/CD workflow YAML, cross-module communication patterns, migration plan

Architecture Decision Records:
- `ADR-001-database-choice.md` — PostgreSQL 16 + PostGIS + TimescaleDB + pgvector
- `ADR-002-spring-vs-quarkus.md` — Spring Boot (CRUD) + Quarkus (high-throughput) hybrid
- `ADR-003-event-backbone.md` — Apache Kafka + Confluent Schema Registry (Avro)
- `ADR-004-angular-over-react.md` — Angular 18 for web dashboard
- `ADR-005-kmp-over-flutter.md` — Kotlin Multiplatform for mobile
- `ADR-006-modular-pluggable-architecture.md` — Modular repos with shared database

---

## Coding Conventions

### Spring Boot Services (M1, M2, M4)
```
com.rpms.{module}/
├── entity/          # JPA entities — 1:1 with DDL tables
├── repository/      # Spring Data JPA repositories
├── service/         # Business logic (interface + implementation)
├── controller/      # REST controllers (@RestController)
├── dto/
│   ├── request/     # Inbound DTOs (Java 21 records with Jakarta validation)
│   └── response/    # Outbound DTOs (Java 21 records — never expose entities)
├── mapper/          # MapStruct interfaces — entity ↔ DTO
├── event/
│   ├── producer/    # Kafka event publishers
│   └── consumer/    # Kafka event consumers from other modules
├── config/          # @Configuration classes
├── exception/       # Module-specific exceptions
└── validation/      # Custom validators
```

### Quarkus Services (M3, M5, M6)
```
com.rpms.{module}/
├── entity/          # Panache entities
├── repository/      # PanacheRepository implementations
├── service/         # Business logic
├── resource/        # JAX-RS resources (@Path)
├── dto/             # DTOs with Jakarta validation
├── mapper/          # MapStruct mappers
├── event/           # SmallRye Reactive Messaging (Kafka)
├── config/          # Quarkus config
└── exception/       # Exception mappers
```

### Angular Module Libraries
```
@rpms/mod-{module}/src/lib/
├── {module}.routes.ts          # Exported route definitions (standalone, lazy-loaded)
├── {module}.nav.ts             # Exported NavItem[] for sidebar registration
├── {module}.providers.ts       # Exported module-specific Angular providers
├── components/                 # Feature components (standalone, OnPush)
├── pages/                      # Routed page components
├── services/                   # API service, state service, WebSocket service
└── models/                     # TypeScript interfaces for module entities
```

### KMP Module Features
```
com.rpms.{module}/ (commonMain)
├── domain/          # Module-specific domain models
├── network/         # Ktor API service
├── database/        # SQLDelight .sq files for offline cache
└── usecase/         # Business logic shared between Android screens

com.rpms.{module}/ (androidMain)
├── ui/
│   ├── {Module}NavGraph.kt    # Compose Navigation graph (exported to shell)
│   └── screens/               # Compose screens
└── hardware/                  # Module-specific hardware (NFC for trees, BLE for tapping)
```

### Shared Rules (All Services)
- Java 21 features: virtual threads, records for DTOs, pattern matching, sealed interfaces for events
- All entities use MapStruct for DTO mapping — never expose JPA entities in REST responses
- All spatial columns use SRID 4326 (WGS 84). GPS point auto-generated from lat/lon via triggers
- Framework-agnostic rule: if a class in `rpms-common` needs a Spring or CDI annotation, it doesn't belong in `rpms-common`
- Angular: standalone components, Reactive Forms, OnPush change detection, strict TypeScript, Angular Material
- KMP: commonMain shared logic (Ktor, SQLDelight, domain models), androidMain for native hardware (BLE, NFC, CameraX)

---

## Key Design Decisions
1. **Modular pluggable architecture** — per-module repos (backend + Angular lib + KMP feature), shared PostgreSQL, thin shell compositors (ADR-006)
2. **Shared database, single writer** — one PostgreSQL instance preserves referential integrity, cross-module JOINs, 30 triggers, 25 views. Each table owned by one module. Enforced via DB permissions.
3. **Spring Boot for stable CRUD** (Plantation, Tree, Workforce) + **Quarkus for high-throughput** (Tapping, Activity, Attendance) (ADR-002)
4. **Kotlin Multiplatform** for mobile — full native Android access to BLE, NFC, CameraX, ForegroundService; iOS via SwiftUI + shared KMP module later (ADR-005)
5. **Angular 18** for web dashboard — Reactive Forms, RxJS for real-time, TypeScript-first, lazy-loaded module libraries (ADR-004)
6. **Apache Kafka** as event backbone — loose coupling, event replay, Avro schema evolution, future module extensibility (ADR-003)
7. **Apache Camel** for edge (MQTT→Kafka) and cloud (external API integration)
8. **Two-tier attendance** — immutable scan_log → derived daily_attendance
9. **PostGIS geometry** throughout — field boundaries (Polygon), GPS routes (LineString), tree positions (Point), geofence zones
10. **JSONB for AI outputs** — flexible schema for evolving ML model responses
11. **Blockchain (Hyperledger)** only for critical provenance — yield, attendance, status changes
12. **Offline-first** everywhere — SQLite at edge gateway, SQLDelight in mobile, store-and-forward sync
13. **Plugin model for future phases** — adding a module = create repo from template + 3 lines in each shell; zero changes to existing modules

---

## Cross-Module Relationships (Foreign Keys)

| From Module | To Module | Key FK | Relationship |
|---|---|---|---|
| M1 (Field Records) | M2 (Tree Records) | `field.field_id` → `tree.field_id` | Trees belong to fields |
| M1 (Field Records) | M3 (Tapping Tasks) | `field.field_id` → `tapping_task.field_id` | Tasks operate on fields |
| M1 (Field Records) | M4 (Workforce) | `plantation_id`, `division_id`, `field_id` | Workers assigned to locations |
| M2 (Tree Records) | M3 (Tapping Tasks) | `tree.tree_id` → `tapping_task_tree_detail.tree_id` | Per-tree tapping data via NFC |
| M4 (Workforce) | M3 (Tapping Tasks) | `worker.worker_id` → `tapping_task.tapper_id` | Tappers assigned to tasks |
| M4 (Workforce) | M5 (Activities) | `worker.worker_id` → `daily_activity.assigned_worker_id` | Workers perform activities |
| M4 (Workforce) | M6 (Attendance) | `worker.worker_id` → `daily_attendance.worker_id` | Attendance per worker |
| M3 (Tapping Tasks) | M5 (Activities) | `tapping_task.task_id` → `daily_activity.tapping_task_id` | Tapping as an activity type |
| M5 (Activities) | M6 (Attendance) | `daily_activity.activity_id` → `daily_attendance.primary_activity_id` | What the worker did that day |

---

## What's Done vs What's Next

### ✅ Completed
- Database schema design (all 6 modules — DDL, diagrams, Mermaid)
- High-level system architecture (updated for modular pluggable architecture)
- Technology decisions with rationale (ADR-001 through ADR-006)
- Modular pluggable architecture design (ADR-006 + detailed implementation guide)
- Repository strategy (10 repos: 1 design + 1 platform + 6 modules + 2 shells)

### 🔲 Not Yet Started (potential next steps)
- rpms-platform repository setup (shared libs, event schemas, gateway, infra)
- API contract design (OpenAPI 3.0 specs per module service)
- Kafka event catalog (event names, Avro schemas, producers/consumers per module)
- Keycloak realm/role/permission design
- Module implementation (M1 → M6, sequentially — each as a separate repo)
- Shell applications (Angular shell + Android shell)
- Angular module library templates (routes, nav items, providers, components)
- KMP feature templates (navigation graphs, Compose screens, hardware integration)
- Wireframes / UI mockups
- Domain-driven design — bounded contexts and context map
- Non-functional requirements document
- Security architecture document

---

## How to Use This Document
Paste this entire document at the start of a new Claude session, then say something like:
- "Continue working on RPMS. Here's the project context. I'd like to work on [specific area] next."
- "Here's my RPMS project context. Please design the API contracts for Module 3 (Tapping Task Monitoring) — this will go in rpms-mod-tapping/api-contract/."
- "Here's my RPMS project context. Create the Kafka event catalog showing which events each module produces and consumes."
- "Here's my RPMS project context. Set up the rpms-platform repository with shared libraries and Avro event schemas."
- "Here's my RPMS project context. Design the Angular shell composition for rpms-shell-web."

Claude will have full context of all design decisions, technology choices, architecture patterns, and completed work.
