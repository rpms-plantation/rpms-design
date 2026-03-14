# RPMS — Rubber Plantation Management System
## Project Context Document (paste this at the start of new Claude sessions)

---

## Project Overview
We are designing and building a **Rubber Plantation Management System (RPMS)** — a comprehensive enterprise platform for managing rubber plantation operations. The system covers field records, individual tree tracking, tapping operations, workforce, daily activities, and attendance — integrated with IoT, Blockchain, Gen AI, AR/MR, and mobile technologies.

---

## Phase 1 — Six Core Modules (COMPLETED: Database Design)

### Module 1: Plantation Field Records Management
- **DDL**: `plantation_field_records_ddl.sql`
- **Tables**: plantation, division, field, nursery, nursery_clone_distribution, plantation_land_use, clone_master, field_lifecycle_history, annual_area_snapshot
- **Lookups**: lu_measurement_unit, lu_land_use_type, lu_nursery_type, lu_field_category, lu_tapping_system
- **Views**: vw_plantation_area_summary, vw_clone_distribution_summary, vw_nursery_clone_summary, vw_immature_fields, vw_mature_fields

### Module 2: Tree Records & Tracking
- **DDL**: `tree_records_tracking_ddl.sql`
- **Core**: tree (BIGSERIAL PK), tree_row, tree_growth_measurement, tree_panel_history, tree_census_summary
- **IoT**: tree_tag (NFC/RFID/QR/BLE)
- **Health**: tree_health_inspection, tree_disease_incident, tree_treatment_record, tree_mortality_record
- **Audit**: tree_status_change_log (with blockchain_tx_hash)
- **Lookups**: lu_tree_status, lu_health_rating, disease_master, lu_treatment_type, lu_growth_parameter, lu_tag_type, lu_mortality_cause
- **Views**: vw_tree_profile, vw_field_tree_summary, vw_disease_hotspot, vw_mortality_analysis
- **Triggers**: Auto-log status changes, sync denormalized girth from measurements, GPS point sync, tag scan counter

### Module 3: Tapping Task Monitoring
- **DDL**: `tapping_task_monitoring_ddl.sql`
- **Core**: tapping_schedule, tapping_task (central hub), tapping_task_tree_detail (NFC per-tree), latex_collection_record, collection_point, weather_observation
- **Quality**: latex_quality_test (DRC, ammonia, pH, VFA testing)
- **IoT**: iot_device, iot_sensor_reading (PARTITIONED by month — TimescaleDB)
- **Analytics**: tapper_performance_daily, field_yield_daily
- **Lookups**: lu_tapping_task_status, lu_latex_grade, lu_tapping_skip_reason, lu_collection_point_type, lu_quality_parameter, lu_iot_device_type
- **Views**: vw_tapping_dashboard_daily, vw_tapper_performance_ranking, vw_clone_yield_analysis, vw_weather_yield_correlation
- **Triggers**: Auto-calc yield_per_tree, auto-calc dry_rubber from DRC, auto-flag out-of-spec quality, GPS sync

### Module 4: Workforce Management
- **DDL**: `workforce_management_ddl.sql`
- **Core**: worker (SERIAL PK — referenced by tapper_id across M3/M5/M6), gang (teams), worker_skill, worker_field_assignment
- **HR**: worker_next_of_kin, worker_document, worker_leave (approval workflow), worker_leave_balance (auto-calc remaining_days GENERATED column), worker_training (VR/MR/classroom methods)
- **Compensation**: worker_pay_structure (multi-component: basic + piece_rate + incentive + deductions)
- **Safety**: worker_safety_incident
- **Audit**: worker_status_change_log (blockchain_tx_hash)
- **Lookups**: lu_worker_category (15 roles), lu_employment_type, lu_worker_status, lu_skill (16 competencies), lu_proficiency_level, lu_leave_type, lu_relationship_type, lu_document_type, lu_pay_component, lu_training_type
- **Views**: vw_worker_profile, vw_gang_roster, vw_expiring_documents, vw_skill_gap_analysis
- **Key**: worker.reports_to_id self-referencing hierarchy; gang current_size auto-sync via trigger; leave balance auto-update on approval

### Module 5: Daily Activity Monitoring
- **DDL**: `daily_activity_monitoring_ddl.sql`
- **Core**: daily_work_plan (container), daily_activity (BIGSERIAL — core entity), activity_worker_assignment (multi-worker)
- **Material**: activity_material_usage, material_master (15 pre-seeded: fertilizers, chemicals, stimulants, fuel)
- **Evidence**: activity_photo_evidence (JSONB ai_analysis_result, geo-tagged)
- **Inspection**: supervisor_inspection (ar_assisted flag, ai_summary), inspection_checklist_response (yes_no / rating_1_5 / numeric / text)
- **Analytics**: daily_activity_summary (AI daily narrative + next-day recommendations)
- **Lookups**: lu_activity_category (15 categories), lu_activity_type (34 specific types), lu_activity_status, lu_activity_priority (with color_hex), lu_inspection_checklist_item
- **Key**: GPS route as GEOMETRY(LineString); JSONB for AI photo analysis; auto-calc completion_pct, man_days, material variance via triggers; plan counts auto-sync

### Module 6: Attendance Management
- **DDL**: `attendance_management_ddl.sql`
- **Core**: daily_attendance (BIGSERIAL — one per worker per day), attendance_scan_log (immutable raw event log)
- **Correction**: attendance_regularization (approval workflow, auto-apply on approval via trigger)
- **Location**: attendance_location (muster points with PostGIS geofence polygons)
- **Roster**: worker_shift_roster (pre-assigned shifts per worker per day)
- **Analytics**: monthly_attendance_summary (payroll-ready: payable_days, OT breakdown, bonus eligibility), plantation_daily_attendance (estate-level snapshot)
- **Lookups**: lu_attendance_status (16 statuses with display_color, is_paid, affects_bonus), lu_checkin_method (8 methods with reliability_score), lu_shift (7 shifts), lu_overtime_type (4 types with multipliers), lu_regularization_reason
- **Key**: Two-tier architecture (scan_log → daily_attendance); auto-calc hours/late/OT via trigger; multi-method check-in with reliability scoring

---

## Technology Stack (FINALIZED)

| Layer | Technology |
|---|---|
| **Backend Services** | Java 21 + Spring Boot 3 (CRUD services) + Quarkus (high-throughput services) |
| **Integration** | Apache Camel 4 (edge + cloud), Apache Kafka (event backbone), Debezium (CDC) |
| **Mobile Apps** | Kotlin Multiplatform + Jetpack Compose (Android), SQLDelight (offline DB), Ktor (networking) |
| **Web Dashboard** | Angular 18 + ngx-charts + ngx-mapbox-gl + RxJS |
| **API Gateway** | Spring Cloud Gateway + Keycloak (OAuth2/OIDC) |
| **Database** | PostgreSQL 16 + PostGIS + TimescaleDB + pgvector |
| **Cache** | Redis 7 |
| **Search** | Elasticsearch 8 |
| **Object Storage** | MinIO / S3 |
| **AI/ML** | Python + FastAPI + PyTorch + LangChain + Claude API |
| **Blockchain** | Hyperledger Fabric (private) |
| **Orchestration** | Temporal.io (saga pattern) |
| **Observability** | OpenTelemetry + Grafana + Prometheus + Loki + Tempo |
| **CI/CD** | GitHub Actions + ArgoCD + Terraform + Kubernetes (EKS/GKE) |
| **Edge** | K3s + Eclipse Mosquitto (MQTT) + Apache Camel |

---

## Database Stats Summary
- **60 core/analytics tables** across 6 modules
- **39 lookup tables** (all pre-seeded with rubber plantation data)
- **25 views** (dashboards, analytics, alerts)
- **30 smart triggers** (auto-calc, auto-sync, GPS point, audit logging)
- **PostgreSQL 16 + PostGIS** for spatial, **TimescaleDB** for IoT time-series

---

## Artifacts Created (18 files)
Each module has 3 artifacts:
1. `.sql` — Complete DDL with tables, indexes, views, triggers, permissions, seed data
2. `.html` — Interactive 4-tab dashboard (ER diagram, table schema cards, relationships table, lifecycle/workflow flow diagram)
3. `.mermaid` — Portable ER diagram for GitHub/Confluence/Notion rendering

Plus:
- `rpms_high_level_architecture.html` — 4-tab interactive architecture (diagram, layer details, tech decisions, deployment)
- `rpms_artifact_storage_strategy.html` — Storage strategy with GitHub repo structure

---

## Artifact Storage Strategy
- **Repo 1**: `rpms-design` — All design artifacts (DDL, diagrams, API contracts, ADRs)
- **Repo 2**: `rpms-backend` — Microservices monorepo (Spring Boot + Quarkus + AI services + infra)
- **Repo 3**: `rpms-mobile` — KMP shared module + Android app (Compose) + Angular web dashboard
- **Wiki**: Notion free tier for living docs, meeting notes, sprint planning
- **All free**: GitHub Free + Notion Free + draw.io + Mermaid

---

## Key Design Decisions
1. **Spring Boot for stable CRUD** (Plantation, Tree, Workforce) + **Quarkus for high-throughput** (Tapping, Activity, Attendance)
2. **Kotlin Multiplatform** for mobile (full native Android access to BLE, NFC, CameraX, ForegroundService) — iOS via SwiftUI + shared KMP module later
3. **Angular 18** for web dashboard (Reactive Forms, RxJS for real-time, TypeScript-first, built-in module structure)
4. **Apache Kafka** as event backbone — loose coupling, event replay, future module extensibility
5. **Apache Camel** for edge (MQTT→Kafka) and cloud (external API integration)
6. **Two-tier attendance** — immutable scan_log → derived daily_attendance
7. **PostGIS geometry** throughout — field boundaries (Polygon), GPS routes (LineString), tree positions (Point), geofence zones
8. **JSONB for AI outputs** — flexible schema for evolving ML model responses
9. **Blockchain (Hyperledger)** only for critical provenance — yield, attendance, status changes
10. **Offline-first** everywhere — SQLite at edge gateway, SQLDelight in mobile, store-and-forward sync

---

## What's Done vs What's Next
### ✅ Completed
- Database schema design (all 6 modules — DDL, diagrams, Mermaid)
- High-level system architecture
- Technology decisions with rationale
- Artifact storage strategy

### 🔲 Not Yet Started (potential next steps)
- API contract design (OpenAPI specs per microservice)
- Detailed Angular module structure and component hierarchy
- KMP shared module design (domain models, Ktor API client)
- Kafka event catalog (event names, Avro schemas, producers/consumers)
- Apache Camel route definitions (edge + cloud)
- Keycloak realm/role/permission design
- Kubernetes deployment manifests / Helm charts
- CI/CD pipeline definitions (GitHub Actions workflows)
- Flyway/Liquibase migration scripts from DDLs
- Wireframes / UI mockups
- Domain-driven design — bounded contexts and context map
- Data flow diagrams per module
- Non-functional requirements document
- Security architecture document

---

## How to Use This Document
Paste this entire document at the start of a new Claude session, then say something like:
- "Continue working on RPMS. Here's the project context. I'd like to work on [specific area] next."
- "Here's my RPMS project context. Please design the API contracts for Module 3 (Tapping Task Monitoring)."
- "Here's my RPMS project context. Create the Kafka event catalog showing which events each module produces and consumes."

Claude will have full context of all design decisions, technology choices, and completed work.
