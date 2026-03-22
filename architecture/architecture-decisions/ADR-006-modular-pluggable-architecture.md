# ADR-006: Adopt Modular Pluggable Architecture with Shared Database

- **Date**: 2026-03-21
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Backend engineering, frontend engineering, DevOps, database engineering
- **Related**: ADR-001 (PostgreSQL — shared database foundation), ADR-002 (Spring Boot + Quarkus — service framework split), ADR-003 (Kafka — event backbone for inter-module communication), ADR-004 (Angular — lazy-loaded module architecture), ADR-005 (KMP — modular Gradle feature structure)

## Context and Problem Statement

The RPMS system comprises six Phase 1 modules distributed across three monorepos: `rpms-design` (design artifacts), `rpms-backend` (all microservices in one Maven multi-module repo), and `rpms-mobile` (KMP shared module + Android app + Angular web dashboard in one Gradle/npm repo). While the runtime architecture is already microservices-based with independent deployment via Kubernetes, the source code organization couples all modules into shared repositories, creating several problems as the system grows.

The specific challenges driving this decision are:

**Coupled release cycles.** A bug fix in the Attendance service (Module 6) requires checking out, building, and potentially redeploying the entire `rpms-backend` monorepo. Even though only `attendance-service/` changed, the CI pipeline builds all eight services. The Angular dashboard has the same problem — changing a single component in the Tapping module triggers a full `rpms-mobile` rebuild.

**Unclear ownership boundaries.** With all services in one repo, there is no enforceable boundary preventing the Tapping service from directly importing Workforce service internals, or the Attendance Angular module from reaching into Plantation module components. Ownership is conventional, not structural.

**Scaling development teams.** As RPMS moves into Phase 2 (Financial, Processing, Supply Chain), potentially 3–5 teams will work on different modules simultaneously. A monorepo with shared CI pipelines and a single `pom.xml` parent creates merge conflicts, long CI queues, and coordination overhead. Each team should be able to develop, test, and release independently.

**Future module extensibility.** Phase 2+ modules (Financial Accounting, Rubber Processing, Supply Chain, Inventory, Sustainability, BI Portal) should be pluggable into the existing system without modifying the core six modules. The architecture must support a "plugin" model where new modules register themselves with the shell applications.

**Shared database is non-negotiable.** The six modules have dense cross-module foreign key relationships. `worker` (Module 4) is referenced by `tapping_task.tapper_id` (M3), `daily_activity.assigned_worker_id` (M5), and `daily_attendance.worker_id` (M6). `field` (Module 1) appears as a FK in 20+ tables across all modules. Additionally, 30 smart triggers auto-calculate values across module boundaries (yield-per-tree, work hours, leave balances), and 25 views JOIN across modules for dashboards. Splitting the database would break referential integrity, disable cross-module JOINs, and require rewriting all triggers as Kafka Streams processors — a massive re-architecture with no proportional benefit at the current scale.

## Decision Drivers

1. **Independent module development** — Each module team can develop, build, test, and release without coordinating with other module teams
2. **Pluggable module registration** — Adding or removing a module from the system requires minimal changes to the shell applications (1 route entry + 1 nav entry + 1 dependency)
3. **Shared database preservation** — All 60 core tables, 39 lookups, 25 views, and 30 triggers continue to work with full referential integrity
4. **Full vertical slice per module** — Backend service, Angular library, KMP feature, API contract, and Flyway migrations colocated in one repository
5. **Consistent shared foundation** — Common DTOs, security, event schemas, and spatial utilities published as versioned platform libraries
6. **Independent CI/CD pipelines** — Each module repo has its own GitHub Actions workflow with parallel build stages
7. **Backward compatibility with existing architecture** — All technology decisions (ADR-001 through ADR-005) remain valid; this is an organizational restructuring, not a technology change

## Considered Options

1. **Modular pluggable repos with shared database** — Per-module repositories, thin shell apps, shared PostgreSQL
2. **Modular repos with database-per-module** — Full independence including separate databases with eventual consistency via Kafka
3. **Monorepo with stricter boundaries** — Keep three repos but enforce module boundaries via build tooling (Nx, Bazel, or Gradle module visibility)
4. **Status quo** — Continue with the current three-repo structure

## Decision Outcome

**Chosen option: Modular pluggable repos with shared database (Option 1)**, because it provides true independent development and deployment for each module while preserving the relational integrity, cross-module JOINs, and trigger-based auto-calculations that are fundamental to the RPMS data model. The shared database is not a compromise — it is the correct choice for a system where modules have dense, legitimate data relationships.

### Repository Structure After Migration

| Repository | Purpose | Contents |
|---|---|---|
| `rpms-platform` | Foundation & shared infrastructure | Shared Java libs (rpms-common, rpms-security, rpms-spatial), Avro event schemas, API gateway, cross-cutting services (notification, reporting), shared DB migrations (V0_xxx), Angular shared library (@rpms/shared), KMP shared module, infrastructure (Terraform, K8s base, Docker) |
| `rpms-mod-plantation` | Module 1 — Plantation Field Records | Spring Boot backend + Flyway V1_xxx + Angular library (@rpms/mod-plantation) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-mod-tree` | Module 2 — Tree Records & Tracking | Spring Boot backend + Flyway V2_xxx + Angular library (@rpms/mod-tree) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-mod-tapping` | Module 3 — Tapping Task Monitoring | Quarkus backend + Flyway V3_xxx + Angular library (@rpms/mod-tapping) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-mod-workforce` | Module 4 — Workforce Management | Spring Boot backend + Flyway V4_xxx + Angular library (@rpms/mod-workforce) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-mod-activity` | Module 5 — Daily Activity Monitoring | Quarkus backend + Flyway V5_xxx + Angular library (@rpms/mod-activity) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-mod-attendance` | Module 6 — Attendance Management | Quarkus backend + Flyway V6_xxx + Angular library (@rpms/mod-attendance) + KMP feature + OpenAPI spec + Avro schemas |
| `rpms-shell-web` | Angular shell application | Thin compositor — layout, sidebar, routing, theme. Composes @rpms/mod-* libraries via lazy-loaded routes. No business logic. |
| `rpms-shell-mobile` | Android shell application | Thin compositor — Compose Navigation host. Composes module KMP features via Gradle dependencies. No business logic. |
| `rpms-design` | Design artifacts (unchanged) | DDL, diagrams, ADRs, API contracts, wireframes |

### Confirmation

This decision will be confirmed successful if:
- A developer can clone a single module repo, build it, and run its tests without cloning any other module repo (platform artifacts pulled from GitHub Packages)
- A bug fix to the Attendance service (rpms-mod-attendance) can be developed, tested, merged, and deployed without rebuilding or redeploying any other module
- Adding a Phase 2 module (e.g., Financial) requires only: creating rpms-mod-finance repo, adding one route entry to rpms-shell-web, one nav entry, and one npm dependency — no changes to existing module repos
- All 25 cross-module views continue to return correct results after migration
- All 30 triggers continue to fire and auto-calculate correctly
- Flyway migrations from different modules (V1_xxx, V3_xxx, V6_xxx) apply cleanly in version order against the shared database
- The full CI/CD pipeline for a single module completes in under 10 minutes (compared to 30+ minutes for the monorepo full build)

## Pros and Cons of the Options

### Option 1: Modular Pluggable Repos with Shared Database (Selected)

Each module gets its own repository containing the full vertical slice (backend + frontend + migrations + contracts). All modules share a single PostgreSQL database. Shell applications are thin compositors that lazy-load module packages.

**Pros:**

- **True independent development and deployment.** Each module repo has its own CI/CD pipeline running in parallel. A push to `rpms-mod-tapping` builds only the Tapping backend (Quarkus), Tapping Angular library, and Tapping KMP feature — not the five other modules. Deployment syncs only the Tapping service's K8s manifests via ArgoCD. Total pipeline time drops from 30+ minutes (monorepo) to under 10 minutes.

- **Enforceable ownership boundaries.** A module repo can only modify its own code. The Tapping team cannot accidentally import Workforce service internals because they are in a separate repository. Cross-module dependencies are explicit: Maven/npm/Gradle dependency declarations on published platform artifacts.

- **Preserves all database capabilities.** Cross-module foreign keys, JOINs, views, triggers, and stored procedures continue to work exactly as designed. The 30 triggers that auto-calculate yield-per-tree, work hours, leave balances, and gang sizes are unchanged. The 25 views that power dashboards continue to operate with full SQL optimization. No eventual consistency complexity, no saga rewriting, no read-model materialization.

- **Plugin model for future phases.** Phase 2 modules create new repos following the same template. The shell apps add one route + one nav entry + one dependency. Existing modules are not modified. This scales linearly — Module 12 is added the same way as Module 7.

- **Shared libraries prevent code duplication.** The `rpms-platform` repo publishes versioned artifacts: `rpms-common` (DTOs, exceptions, utilities), `rpms-security` (Keycloak integration for both Spring Boot and Quarkus), `rpms-spatial` (PostGIS helpers), and `@rpms/shared` (Angular shared components). All modules depend on these artifacts rather than copying code.

- **Flyway migration ordering is natural.** Module-prefixed version numbers (V0_xxx for platform, V1_xxx for M1, V3_xxx for M3) ensure correct ordering without coordination. Flyway processes them in natural sort order. Each module team only manages its own prefix range.

- **Compatible with existing technology decisions.** All five previous ADRs remain valid. Spring Boot and Quarkus services are separated as per ADR-002. Kafka events flow as per ADR-003. Angular lazy-loading works as per ADR-004. KMP Gradle modules work as per ADR-005. The database schema from ADR-001 is unchanged.

**Cons:**

- **Distributed source code increases navigation overhead.** A developer debugging a cross-module issue (e.g., attendance records not reflecting a workforce status change) must navigate two repos. Mitigated by: Kafka event contract tests (Pact) that catch integration breakage at CI time, and OpenAPI specs that document each module's API surface.

- **Platform library versioning requires discipline.** When `rpms-common` publishes a new version (e.g., adding a field to `WorkerRef`), all six module repos must update their dependency version. Mitigated by: semantic versioning (backward-compatible changes within the same major version), Dependabot for automated version bump PRs, and a CI check that validates each module against the latest platform version.

- **Flyway migration conflicts are possible but unlikely.** If Module 3 and Module 5 both add migrations in the same release window, the version numbers are in different ranges (V3_xxx vs V5_xxx) and cannot collide. The only risk is if both migrations modify the same table — but the ownership rule (one module writes, others read) prevents this by convention.

- **Shell app rebuild on module update.** When a module publishes a new Angular library version, the shell app must rebuild to pick it up. Mitigated by: module webhook triggers that automatically create a PR in the shell repo with the updated dependency version. The shell rebuild is fast (< 3 minutes) since it contains no business logic.

- **Nine repositories to manage.** More repos mean more GitHub configuration (branch protection, secrets, webhooks). Mitigated by: Terraform-managed GitHub repo configuration, a shared `.github/` template repo, and consistent naming conventions.

### Option 2: Modular Repos with Database-per-Module

Full independence including separate PostgreSQL databases per module. Cross-module data access via Kafka event-driven read models.

**Pros:**
- Complete deployment independence — no shared database migration coordination
- Each module can choose its own database technology (though all currently use PostgreSQL)
- True microservice isolation — no runtime coupling at the data layer

**Cons:**
- **Breaks 25 cross-module views.** Views like `vw_field_tree_summary` (joins M1 and M2), `vw_worker_attendance_calendar` (joins M4 and M6), and `vw_daily_activity_summary` (joins M1, M4, M5) would need to be replaced with API composition or materialized views maintained by Kafka consumers. This is 2–4 weeks of re-architecture work with increased complexity and reduced query performance.
- **Breaks 30 triggers.** Triggers like `trg_update_daily_attendance` (which references `worker`, `daily_activity`, and `attendance_scan_log` across M4, M5, M6) cannot operate across databases. Each trigger would need to be reimplemented as a Kafka Streams processor or Temporal saga step.
- **Breaks cross-module foreign key integrity.** The `worker_id` in `daily_attendance` would no longer be enforced by PostgreSQL. Invalid references (e.g., attendance records for deleted workers) would only be caught by application-level validation — weaker and more error-prone.
- **Introduces eventual consistency for every cross-module query.** A manager viewing the plantation dashboard would see stale data depending on consumer lag. The current architecture provides consistent reads via SQL JOINs.
- **Disproportionate effort-to-benefit ratio.** The operational overhead of managing six PostgreSQL databases, six Flyway pipelines, read-model materialization, and saga-based consistency for every cross-module interaction is not justified when a single shared database handles the current and projected data volume comfortably.

### Option 3: Monorepo with Stricter Boundaries

Keep the current three-repo structure but use build tooling (Nx for Angular, Maven module visibility for Java, Gradle module access restrictions for KMP) to enforce module boundaries.

**Pros:**
- Single checkout for all modules — easier cross-module debugging
- Atomic commits that span modules (useful during Phase 1 when a single developer builds everything)
- Established tooling (Nx, Turborepo) with good Angular support

**Cons:**
- CI pipeline still builds/tests all modules on every push. Build caching helps but doesn't eliminate the problem.
- Ownership enforcement is tooling-based (Nx project boundaries, CODEOWNERS) rather than structural. A determined developer can still bypass boundaries.
- Does not enable independent release cycles. Deploying Module 6 still requires a release from the monorepo.
- Scaling to 5+ teams in a monorepo creates merge queue bottleneck.

### Option 4: Status Quo (Three Repos)

Continue with `rpms-design`, `rpms-backend`, and `rpms-mobile`.

**Pros:**
- No migration effort
- Simpler for a single developer

**Cons:**
- All the problems described in the Context section persist and worsen as Phase 2 modules are added.
- Not viable for multi-team development.

## Implementation Plan

### Phase 1: Extract rpms-platform (Week 1–2)

1. Create `rpms-platform` repo
2. Move `shared-libs/` (rpms-common, rpms-security, rpms-kafka-events) from rpms-backend
3. Add rpms-spatial shared library
4. Configure GitHub Packages publication (Maven + npm)
5. Move API gateway from rpms-backend to rpms-platform
6. Move notification-service and reporting-service to rpms-platform
7. Create shared Flyway migrations (V0_xxx) from the common DDL objects (extensions, lookups, cross-module views, cross-module triggers)
8. Create `angular-shared/` library from rpms-mobile's `shared/` components
9. Create `kmp-shared/` module from rpms-mobile's `shared/` KMP code
10. Publish all platform artifacts v1.0.0

### Phase 2: Extract Module Repos (Week 3–5)

For each module (M1 through M6), sequentially:
1. Create `rpms-mod-{name}` repo from template
2. Move backend service from rpms-backend monorepo
3. Extract Angular feature module into publishable library
4. Extract KMP feature into publishable Gradle module
5. Create module-prefixed Flyway migrations from existing DDL
6. Move OpenAPI spec and Avro schemas
7. Configure CI/CD pipeline
8. Verify module builds and tests independently against platform artifacts
9. Deploy and validate in staging

### Phase 3: Create Shell Apps (Week 6)

1. Create `rpms-shell-web` — thin Angular compositor
2. Create `rpms-shell-mobile` — thin Compose Navigation host
3. Wire up all six module packages via lazy loading
4. Configure webhook triggers from module repos to shell repos
5. Full integration testing
6. Production deployment

### Phase 4: Decommission Monorepos (Week 7)

1. Archive `rpms-backend` (keep for git history reference)
2. Archive Angular/KMP code in `rpms-mobile` (keep for git history reference)
3. Update `rpms-design` README to reference new repo structure

## Database Ownership Model

### Single Writer, Many Readers

Each database table has exactly one module that writes to it. Any module can read from any table via its database connection (shared database). This avoids distributed transactions while maintaining referential integrity.

| Module | Writes To (owns) | Reads From (cross-module) |
|---|---|---|
| M1 Plantation | plantation, division, field, nursery, clone_master, field_lifecycle_history, annual_area_snapshot | — (foundation module) |
| M2 Tree | tree, tree_row, tree_tag, tree_growth_measurement, tree_panel_history, tree_health_inspection, tree_disease_incident, tree_treatment_record, tree_mortality_record, tree_census_summary | plantation, field, clone_master (M1) |
| M3 Tapping | tapping_schedule, tapping_task, tapping_task_tree_detail, latex_collection_record, collection_point, latex_quality_test, weather_observation, iot_device, iot_sensor_reading | field (M1), tree (M2), worker (M4) |
| M4 Workforce | worker, gang, worker_skill, worker_document, worker_leave, worker_leave_balance, worker_training, worker_pay_structure, worker_safety_incident, worker_status_change_log | plantation, division, field (M1) |
| M5 Activity | daily_work_plan, daily_activity, activity_worker_assignment, activity_material_usage, activity_photo_evidence, supervisor_inspection, inspection_checklist_response, daily_activity_summary | plantation, division, field (M1), worker, gang (M4), tapping_task (M3) |
| M6 Attendance | attendance_scan_log, daily_attendance, shift_roster, overtime_record, attendance_regularization, monthly_attendance_summary | plantation, division (M1), worker, gang, worker_leave (M4), daily_activity (M5), iot_device (M3) |

### Migration Prefix Convention

| Prefix | Owner | Example |
|---|---|---|
| V0_xxx | rpms-platform | V0_001__extensions.sql, V0_002__shared_lookups.sql, V0_003__cross_module_views.sql |
| V1_xxx | rpms-mod-plantation | V1_001__create_plantation.sql, V1_002__create_field.sql |
| V2_xxx | rpms-mod-tree | V2_001__create_tree.sql, V2_002__create_tree_tag.sql |
| V3_xxx | rpms-mod-tapping | V3_001__create_tapping_task.sql, V3_002__create_latex_collection.sql |
| V4_xxx | rpms-mod-workforce | V4_001__create_worker.sql, V4_002__create_gang.sql |
| V5_xxx | rpms-mod-activity | V5_001__create_daily_work_plan.sql, V5_002__create_daily_activity.sql |
| V6_xxx | rpms-mod-attendance | V6_001__create_scan_log.sql, V6_002__create_daily_attendance.sql |

### Cross-Module Objects in Platform (V0_xxx)

The following database objects span module boundaries and are owned by `rpms-platform`:

- **39 lookup tables** (lu_*) — referenced by multiple modules
- **25 cross-module views** — JOIN across module tables for dashboards
- **Cross-module triggers** — triggers that read from tables owned by different modules (e.g., trg_update_daily_attendance reads worker from M4 and activity from M5)

## Consequences

### Positive

- Each module team can develop, test, build, and deploy independently. CI pipeline time per module drops from 30+ minutes (monorepo full build) to under 10 minutes.
- Module ownership is structurally enforced — a module repo cannot modify code in another module's repo.
- Adding Phase 2 modules requires creating a new repo from a template and adding three lines to each shell app (route, nav item, dependency). No existing module code is modified.
- All 25 cross-module views, 30 triggers, and full referential integrity are preserved. Zero data architecture changes.
- The shared database eliminates distributed transaction complexity, eventual consistency challenges, and read-model synchronization overhead.

### Negative

- Nine repositories to manage instead of three. GitHub configuration (branch protection, secrets, Actions workflows) must be templated and automated.
- Platform library version bumps propagate to all module repos. Requires Dependabot or Renovate automation.
- Developers debugging cross-module issues must navigate multiple repos. Mitigated by contract tests and clear API documentation.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Platform library breaking change affects all modules | Low | High | Semantic versioning with BACKWARD compatibility. CI validates modules against latest platform version. Breaking changes go through RFC process. |
| Flyway migration from one module breaks another module's table | Low | High | Single-writer rule: only the owning module writes migrations for its tables. CI validates Flyway migration order against staging database. |
| Shell app breaks due to incompatible module library update | Medium | Medium | Contract-based integration: each module exports a stable public API (routes, nav items, providers). Pact contract tests verify compatibility. Shell rebuilds are automated via webhook + PR. |
| Developer bypasses single-writer rule by directly writing to another module's table | Medium | Medium | Database-level enforcement via PostgreSQL schema permissions: each module's service account has WRITE access only to its own tables, READ access to all. Platform triggers/views run as the platform service account. |

## Links

- **Related ADRs**: ADR-001 (PostgreSQL shared database foundation), ADR-002 (Spring Boot + Quarkus framework split), ADR-003 (Kafka event backbone), ADR-004 (Angular lazy-loaded modules), ADR-005 (KMP modular features)
- **Design artifacts**: [`rpms-design/architecture/rpms_high_level_architecture.html`](../rpms_high_level_architecture.html) — Layer 5 (Microservices)
- **Implementation guide**: [`rpms-design/architecture/modular-architecture-implementation-guide.md`](../modular-architecture-implementation-guide.md)
