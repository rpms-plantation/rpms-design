# Modular Pluggable Architecture — Implementation Guide

> **RPMS Rubber Plantation Management System**
> Reference: ADR-006 — Modular Pluggable Architecture with Shared Database
> Last Updated: 2026-03-21

---

## Table of Contents

- [Overview](#overview)
- [Repository Map](#repository-map)
- [rpms-platform Repository](#rpms-platform-repository)
- [Module Repository Template](#module-repository-template)
- [Angular Shell Composition](#angular-shell-composition)
- [Android Shell Composition](#android-shell-composition)
- [Database Ownership Model](#database-ownership-model)
- [Flyway Migration Strategy](#flyway-migration-strategy)
- [CI/CD Pipeline per Module](#cicd-pipeline-per-module)
- [Shared Library Contracts](#shared-library-contracts)
- [Cross-Module Communication Patterns](#cross-module-communication-patterns)
- [Platform Library Versioning](#platform-library-versioning)
- [Pact Contract Testing](#pact-contract-testing)
- [Migration Plan from Monorepo](#migration-plan-from-monorepo)

---

## Overview

The RPMS modular pluggable architecture separates each business module into its own repository containing a full vertical slice — backend service, Angular library, KMP feature, API contract, and Flyway migrations — while sharing a single PostgreSQL 16 database. Thin shell applications (Angular web, Android Compose) lazy-load module packages at runtime.

**Core principles:**

- **One repo per module** — full vertical slice, independent CI/CD, independent release cycle
- **Shared database** — all 60 tables, 39 lookups, 25 views, 30 triggers intact with full referential integrity
- **Single writer, many readers** — each table has exactly one module that writes to it; any module can read from any table
- **Platform foundation** — shared Java libraries, event schemas, Angular/KMP shared packages published as versioned artifacts
- **Thin shell compositors** — shell apps contain zero business logic; they compose module packages via lazy loading
- **Plugin model** — adding a module = 1 route + 1 nav entry + 1 dependency in each shell

---

## Repository Map

```
rpms-plantation (GitHub Organization)
│
├── rpms-design               # Design artifacts, DDL, diagrams, ADRs (unchanged)
│
├── rpms-platform              # Foundation: shared libs, gateway, cross-cutting services, infra
│
├── rpms-mod-plantation        # M1 — Spring Boot backend + Angular lib + KMP feature
├── rpms-mod-tree              # M2 — Spring Boot backend + Angular lib + KMP feature
├── rpms-mod-tapping           # M3 — Quarkus backend + Angular lib + KMP feature
├── rpms-mod-workforce         # M4 — Spring Boot backend + Angular lib + KMP feature
├── rpms-mod-activity          # M5 — Quarkus backend + Angular lib + KMP feature
├── rpms-mod-attendance        # M6 — Quarkus backend + Angular lib + KMP feature
│
├── rpms-shell-web             # Angular shell app (thin compositor)
└── rpms-shell-android         # Android shell app (thin compositor)
```

**Total: 10 repositories** (rpms-design unchanged + rpms-platform + 6 modules + 2 shells)

---

## rpms-platform Repository

The foundation that every module depends on. Changes rarely, versioned carefully.

### Directory Structure

```
rpms-platform/
│
├── shared-libs/                              # Java libraries → GitHub Packages (Maven)
│   │
│   ├── rpms-common/                          # Framework-agnostic shared code
│   │   ├── src/main/java/com/rpms/common/
│   │   │   ├── dto/
│   │   │   │   ├── PlantationRef.java        # record(int id, String code, String name)
│   │   │   │   ├── FieldRef.java             # record(int id, String fieldCode, String fieldName)
│   │   │   │   ├── WorkerRef.java            # record(int id, String employeeCode, String fullName)
│   │   │   │   ├── DivisionRef.java          # record(int id, String divisionCode, String divisionName)
│   │   │   │   ├── CloneRef.java             # record(int id, String cloneCode, String cloneName)
│   │   │   │   ├── GangRef.java              # record(int id, String gangCode, String gangName)
│   │   │   │   └── PageResponse.java         # record<T>(List<T> content, int page, int size, long total)
│   │   │   ├── event/
│   │   │   │   ├── DomainEvent.java          # sealed interface — base for all domain events
│   │   │   │   ├── EventMetadata.java        # record(UUID eventId, Instant timestamp, String source, String correlationId)
│   │   │   │   └── EventPublisher.java       # interface — framework-agnostic publish contract
│   │   │   ├── exception/
│   │   │   │   ├── RpmsException.java        # abstract base with error code
│   │   │   │   ├── EntityNotFoundException.java
│   │   │   │   ├── BusinessRuleViolation.java
│   │   │   │   ├── ConcurrencyConflictException.java
│   │   │   │   └── ValidationException.java
│   │   │   ├── validation/
│   │   │   │   ├── GpsCoordinate.java        # Jakarta @Constraint for lat/lon range
│   │   │   │   ├── GpsCoordinateValidator.java
│   │   │   │   ├── DateRangeValid.java       # Cross-field start <= end validation
│   │   │   │   └── DateRangeValidator.java
│   │   │   ├── util/
│   │   │   │   ├── SpatialUtils.java         # WKT ↔ GeoJSON, distance calculation
│   │   │   │   ├── DateUtils.java            # Plantation calendar, tapping day helpers
│   │   │   │   └── SlugUtils.java            # Code generation for entity codes
│   │   │   └── constant/
│   │   │       ├── Srid.java                 # public static final int WGS84 = 4326;
│   │   │       ├── KafkaTopics.java          # Topic name constants
│   │   │       └── RpmsHeaders.java          # HTTP header names (X-Plantation-Id, etc.)
│   │   └── pom.xml                           # Pure Java 21 — NO Spring/CDI annotations
│   │
│   ├── rpms-security/                        # Keycloak JWT integration (dual framework)
│   │   ├── src/main/java/com/rpms/security/
│   │   │   ├── model/
│   │   │   │   ├── RpmsUserPrincipal.java    # record(String sub, String name, Set<RpmsRole> roles, int plantationId)
│   │   │   │   ├── RpmsRole.java             # enum: SYSTEM_ADMIN, ESTATE_MANAGER, DIVISION_CONDUCTOR, FIELD_SUPERVISOR, TAPPER, COLLECTOR, CLERK, MEDICAL_OFFICER
│   │   │   │   └── RpmsPermission.java       # enum: PLANTATION_READ, PLANTATION_WRITE, TREE_READ, TREE_WRITE, TASK_ASSIGN, ATTENDANCE_APPROVE, ...
│   │   │   ├── spring/                       # Auto-configured for Spring Boot services
│   │   │   │   ├── SpringSecurityConfig.java # @Configuration — JWT resource server + role mapping
│   │   │   │   └── KeycloakJwtConverter.java # Extracts RpmsUserPrincipal from JWT claims
│   │   │   └── quarkus/                      # Auto-configured for Quarkus services
│   │   │       ├── QuarkusSecurityConfig.java
│   │   │       └── QuarkusJwtConverter.java
│   │   └── pom.xml
│   │
│   ├── rpms-spatial/                         # PostGIS helpers
│   │   ├── src/main/java/com/rpms/spatial/
│   │   │   ├── GeoJsonConverter.java         # PostGIS geometry ↔ GeoJSON DTO conversion
│   │   │   ├── PointFactory.java             # Create SRID 4326 points from lat/lon
│   │   │   ├── BoundingBox.java              # record(double minLon, minLat, maxLon, maxLat)
│   │   │   └── SpatialQueryHelper.java       # ST_Within, ST_DWithin query builder helpers
│   │   └── pom.xml
│   │
│   └── pom.xml                               # Parent POM — dependency BOM, plugin management
│
├── event-schemas/                            # Avro schemas → GitHub Packages (Maven JAR)
│   ├── src/main/avro/
│   │   ├── common/
│   │   │   ├── EventMetadata.avsc            # Shared envelope: eventId, timestamp, source, correlationId
│   │   │   └── GpsPoint.avsc                 # latitude, longitude (double)
│   │   ├── plantation/
│   │   │   ├── PlantationCreated.avsc
│   │   │   └── FieldStatusChanged.avsc
│   │   ├── tree/
│   │   │   ├── TreeStatusChanged.avsc
│   │   │   └── DiseaseIncidentDetected.avsc
│   │   ├── tapping/
│   │   │   ├── TappingTaskCompleted.avsc
│   │   │   ├── LatexCollected.avsc
│   │   │   └── QualityTestFailed.avsc
│   │   ├── workforce/
│   │   │   ├── WorkerStatusChanged.avsc
│   │   │   ├── LeaveApproved.avsc
│   │   │   └── WorkerTransferred.avsc
│   │   ├── activity/
│   │   │   ├── ActivityCompleted.avsc
│   │   │   └── InspectionFailed.avsc
│   │   ├── attendance/
│   │   │   ├── AttendanceScanReceived.avsc
│   │   │   └── DailyAttendanceFinalized.avsc
│   │   └── iot/
│   │       └── IoTSensorReading.avsc
│   ├── src/main/resources/
│   │   └── topic-registry.yaml               # Full Kafka topic catalog with partition keys, retention, consumers
│   └── pom.xml                               # Avro Maven plugin → generates Java classes
│
├── api-gateway/                              # Spring Cloud Gateway
│   ├── src/main/java/com/rpms/gateway/
│   │   ├── GatewayApplication.java
│   │   ├── config/
│   │   │   ├── RouteConfig.java              # Programmatic route definitions per module
│   │   │   ├── CorsConfig.java               # Allowed origins for Angular/mobile
│   │   │   └── RateLimitConfig.java          # Per-client rate limiting via Redis
│   │   └── filter/
│   │       ├── JwtRelayFilter.java           # Forwards Keycloak JWT to downstream services
│   │       ├── RequestLoggingFilter.java     # Structured logging with correlation ID
│   │       └── TenantContextFilter.java      # Extracts plantation_id from JWT → header
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   └── routes.yml                        # Declarative route-to-service mapping
│   ├── Dockerfile
│   └── pom.xml
│
├── services/                                 # Cross-cutting services (not module-specific)
│   ├── notification-service/                 # Spring Boot — FCM push, Twilio SMS, email
│   │   ├── src/main/java/com/rpms/notification/
│   │   ├── Dockerfile
│   │   └── pom.xml
│   └── reporting-service/                    # Spring Boot — JasperReports, OLAP rollups
│       ├── src/main/java/com/rpms/reporting/
│       ├── Dockerfile
│       └── pom.xml
│
├── database/                                 # Cross-module database objects
│   └── migrations/
│       ├── V0_001__create_extensions.sql             # postgis, uuid-ossp, timescaledb
│       ├── V0_002__create_shared_lookup_tables.sql   # All 39 lu_* tables + seed data
│       ├── V0_003__create_cross_module_views.sql     # 25 views (vw_field_tree_summary, vw_worker_attendance_calendar, etc.)
│       ├── V0_004__create_cross_module_triggers.sql  # Triggers spanning module boundaries
│       └── V0_005__create_shared_functions.sql       # Shared PL/pgSQL functions
│
├── angular-shared/                           # Published as @rpms/shared on npm (GitHub Packages)
│   ├── src/lib/
│   │   ├── components/
│   │   │   ├── map-viewer/                   # ngx-mapbox-gl wrapper with field boundary + tree point layers
│   │   │   │   ├── map-viewer.component.ts
│   │   │   │   ├── map-viewer.component.html
│   │   │   │   └── map-viewer.component.scss
│   │   │   ├── data-table/                   # Configurable table — sort, filter, paginate, export
│   │   │   │   ├── data-table.component.ts
│   │   │   │   └── column-def.model.ts
│   │   │   ├── chart-panel/                  # ngx-charts wrapper with standard themes
│   │   │   │   └── chart-panel.component.ts
│   │   │   ├── photo-gallery/                # MinIO/S3 photo viewer with zoom
│   │   │   │   └── photo-gallery.component.ts
│   │   │   ├── entity-selector/              # Reusable plantation/division/field/worker cascading picker
│   │   │   │   └── entity-selector.component.ts
│   │   │   └── status-badge/                 # Generic color-coded status chip
│   │   │       └── status-badge.component.ts
│   │   ├── services/
│   │   │   ├── auth.service.ts               # Keycloak OIDC login/logout/token refresh
│   │   │   ├── websocket.service.ts          # RxJS WebSocket connection manager
│   │   │   ├── notification.service.ts       # Snackbar/toast display manager
│   │   │   └── api-base.service.ts           # Base HTTP service with pagination, error handling
│   │   ├── interceptors/
│   │   │   ├── jwt.interceptor.ts            # Attaches Bearer token from auth.service
│   │   │   ├── error.interceptor.ts          # Global error → notification.service
│   │   │   └── loading.interceptor.ts        # Manages loading spinner state
│   │   ├── guards/
│   │   │   ├── auth.guard.ts                 # Redirects to login if not authenticated
│   │   │   └── role.guard.ts                 # Checks RpmsRole against route data
│   │   ├── models/
│   │   │   ├── plantation-ref.model.ts       # interface { id: number; code: string; name: string }
│   │   │   ├── field-ref.model.ts
│   │   │   ├── worker-ref.model.ts
│   │   │   ├── division-ref.model.ts
│   │   │   ├── page-response.model.ts        # interface PageResponse<T> { content: T[]; page: number; size: number; totalElements: number }
│   │   │   └── nav-item.model.ts             # interface NavItem { label, icon, route, roles, children? }
│   │   ├── pipes/
│   │   │   ├── hectares.pipe.ts              # Formats area in hectares with locale
│   │   │   ├── gps-format.pipe.ts            # Formats GPS coordinates (DMS or decimal)
│   │   │   └── time-ago.pipe.ts              # "5 minutes ago" relative time
│   │   └── directives/
│   │       ├── has-role.directive.ts          # *rpmsHasRole="['MANAGER']" structural directive
│   │       └── auto-focus.directive.ts
│   ├── ng-package.json
│   ├── package.json                          # @rpms/shared
│   └── tsconfig.lib.json
│
├── kmp-shared/                               # Published as com.rpms:shared-kmp (Maven)
│   ├── src/
│   │   ├── commonMain/kotlin/com/rpms/shared/
│   │   │   ├── domain/
│   │   │   │   ├── PlantationRef.kt          # data class PlantationRef(val id: Int, val code: String, val name: String)
│   │   │   │   ├── FieldRef.kt
│   │   │   │   ├── WorkerRef.kt
│   │   │   │   ├── DivisionRef.kt
│   │   │   │   └── GpsPoint.kt               # data class GpsPoint(val latitude: Double, val longitude: Double)
│   │   │   ├── network/
│   │   │   │   ├── RpmsHttpClient.kt         # Ktor client factory with Keycloak token refresh
│   │   │   │   ├── ApiResult.kt              # sealed class: Success<T>, Error(code, message), Loading
│   │   │   │   └── interceptor/
│   │   │   │       └── AuthInterceptor.kt    # Injects Bearer token into requests
│   │   │   ├── database/
│   │   │   │   ├── BaseSyncManager.kt        # Store-and-forward sync engine (SQLDelight ↔ REST)
│   │   │   │   └── ConflictResolver.kt       # Last-write-wins with server-priority
│   │   │   └── validation/
│   │   │       └── GpsValidator.kt           # Latitude -90..90, Longitude -180..180
│   │   └── androidMain/kotlin/com/rpms/shared/
│   │       └── PlatformUtils.kt              # Android-specific implementations
│   └── build.gradle.kts
│
├── infra/
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── prod/
│   │   └── modules/
│   │       ├── kubernetes/                   # EKS/GKE cluster provisioning
│   │       ├── database/                     # RDS PostgreSQL + PostGIS
│   │       ├── kafka/                        # MSK or Confluent Cloud
│   │       ├── redis/                        # ElastiCache
│   │       └── networking/                   # VPC, subnets, security groups
│   ├── k8s-manifests/
│   │   └── base/                             # Namespaces, configmaps, secrets, RBAC
│   ├── docker/
│   │   ├── docker-compose.dev.yml            # Full local stack: PG+PostGIS, Kafka, Redis, Keycloak, MinIO, Elasticsearch
│   │   ├── Dockerfile.spring                 # Shared multi-stage build for Spring Boot services
│   │   └── Dockerfile.quarkus                # Shared multi-stage build for Quarkus services
│   └── edge-gateway/
│       ├── mosquitto/
│       │   └── mosquitto.conf
│       └── camel-edge/
│           └── routes.yaml
│
├── .github/
│   └── workflows/
│       ├── ci-shared-libs.yml                # Build + test + publish rpms-common, rpms-security, rpms-spatial
│       ├── ci-event-schemas.yml              # Avro codegen + Schema Registry compatibility check + publish JAR
│       ├── ci-angular-shared.yml             # Build + test + publish @rpms/shared
│       ├── ci-kmp-shared.yml                 # Build + test + publish com.rpms:shared-kmp
│       ├── ci-gateway.yml                    # Build + test + Docker push + ArgoCD sync for API gateway
│       ├── ci-cross-cutting.yml              # Build + deploy notification-service, reporting-service
│       └── cd-infra.yml                      # Terraform plan (PR) / apply (main)
│
├── pom.xml                                   # Root parent POM — BOM for all dependency versions
└── README.md
```

### Framework-Agnostic Design Rule

> **If a class in `rpms-common` needs a Spring or CDI annotation, it does not belong in `rpms-common`.**

The `rpms-security` library is the sole exception — it contains framework-specific sub-packages (`spring/` and `quarkus/`) with each module pulling only its relevant package via Maven profiles.

All DTOs in `rpms-common` use Java 21 records with Jakarta Bean Validation annotations (shared by both Spring Boot and Quarkus):

```java
// rpms-common — com.rpms.common.dto.WorkerRef.java
public record WorkerRef(
    int id,
    @NotBlank String employeeCode,
    @NotBlank String fullName
) {}
```

### Platform Versioning

All shared-libs artifacts follow semantic versioning and are published together:

- `com.rpms:rpms-common:1.x.y`
- `com.rpms:rpms-security:1.x.y`
- `com.rpms:rpms-spatial:1.x.y`
- `com.rpms:rpms-kafka-events:1.x.y`
- `@rpms/shared` npm package: `1.x.y`
- `com.rpms:shared-kmp:1.x.y`

**Version bump rules:**
- **Patch (1.0.x)**: Bug fixes, documentation updates
- **Minor (1.x.0)**: New DTOs, new event schemas (with Avro BACKWARD compatibility), new Angular components, new KMP functions
- **Major (x.0.0)**: Removing/renaming DTOs, breaking Avro schema changes (new topic version created), removing Angular components

---

## Module Repository Template

Every module repo follows the same internal structure. Replace `{module}` and `{Module}` accordingly.

### Directory Structure

```
rpms-mod-{module}/
│
├── backend/
│   ├── src/main/java/com/rpms/{module}/
│   │   ├── entity/                   # JPA entities (Spring Boot) or Panache entities (Quarkus)
│   │   ├── repository/               # Spring Data JPA or PanacheRepository
│   │   ├── service/                  # Business logic (interface + implementation)
│   │   ├── controller/               # @RestController (Spring) or @Path resource (Quarkus)
│   │   ├── dto/
│   │   │   ├── request/              # Inbound DTOs (Java records with Jakarta validation)
│   │   │   └── response/             # Outbound DTOs (Java records, never expose entities)
│   │   ├── mapper/                   # MapStruct interfaces — entity ↔ DTO mapping
│   │   ├── event/
│   │   │   ├── producer/             # Kafka event publishers for this module
│   │   │   └── consumer/             # Kafka event consumers from other modules
│   │   ├── config/                   # Framework configuration classes
│   │   ├── exception/                # Module-specific exceptions
│   │   └── validation/               # Custom validators
│   ├── src/main/resources/
│   │   ├── application.yml           # Service config (datasource, kafka, keycloak)
│   │   └── db/migration/             # Flyway migrations (V{N}_xxx prefix)
│   ├── src/test/
│   │   ├── java/com/rpms/{module}/
│   │   │   ├── service/              # Unit tests (JUnit 5 + Mockito)
│   │   │   ├── repository/           # Integration tests (Testcontainers + PostGIS)
│   │   │   ├── controller/           # API tests (REST Assured)
│   │   │   └── event/                # Kafka tests (Testcontainers + embedded Kafka)
│   │   └── resources/
│   │       └── application-test.yml
│   ├── pom.xml                       # Depends on rpms-common, rpms-security, rpms-kafka-events
│   └── Dockerfile
│
├── angular-lib/                      # Published as @rpms/mod-{module} on npm
│   ├── src/
│   │   ├── lib/
│   │   │   ├── {module}.routes.ts    # Module route definitions (standalone, lazy-loaded)
│   │   │   ├── {module}.nav.ts       # NavItem[] for sidebar registration
│   │   │   ├── {module}.providers.ts # Module-specific Angular providers
│   │   │   ├── components/           # Feature components (standalone, OnPush)
│   │   │   ├── pages/                # Routed page components
│   │   │   ├── services/             # API service, state service, WebSocket service
│   │   │   └── models/               # TypeScript interfaces for module entities
│   │   └── public-api.ts             # Barrel export — ONLY export routes, nav, providers, embeddable widgets
│   ├── ng-package.json
│   ├── package.json                  # @rpms/mod-{module}, depends on @rpms/shared
│   └── tsconfig.lib.json
│
├── kmp-feature/                      # Published as com.rpms:mod-{module}-kmp (Maven)
│   ├── src/
│   │   ├── commonMain/kotlin/com/rpms/{module}/
│   │   │   ├── domain/               # Module-specific domain models
│   │   │   ├── network/              # Ktor API service for this module
│   │   │   ├── database/             # SQLDelight .sq files for offline cache
│   │   │   └── usecase/              # Business logic (shared between Android screens)
│   │   └── androidMain/kotlin/com/rpms/{module}/
│   │       ├── ui/                   # Jetpack Compose screens
│   │       │   ├── {Module}NavGraph.kt   # Navigation graph for this module
│   │       │   └── screens/
│   │       └── hardware/             # Module-specific hardware (NFC for trees, BLE for tapping)
│   └── build.gradle.kts              # Depends on com.rpms:shared-kmp
│
├── api-contract/
│   ├── {module}-service-openapi.yaml # OpenAPI 3.0 specification
│   └── events/                       # Module-specific Avro schemas (if any beyond platform events)
│       └── {Module}SpecificEvent.avsc
│
├── k8s/
│   ├── deployment.yaml               # K8s Deployment manifest
│   ├── service.yaml                   # K8s Service manifest
│   ├── hpa.yaml                       # HorizontalPodAutoscaler (Quarkus services)
│   └── kustomization.yaml
│
├── .github/
│   └── workflows/
│       └── ci.yml                     # Full CI/CD pipeline (see CI/CD section below)
│
├── CLAUDE.md                          # AI coding assistant configuration
└── README.md
```

---

## Angular Shell Composition

### rpms-shell-web Directory Structure

```
rpms-shell-web/
├── src/
│   ├── app/
│   │   ├── layout/
│   │   │   ├── layout.component.ts        # Shell layout: sidebar + topbar + <router-outlet>
│   │   │   ├── sidebar.component.ts       # Renders nav items filtered by user role
│   │   │   ├── topbar.component.ts        # User menu, notifications, plantation selector
│   │   │   └── nav-registry.ts            # Collects NavItem[] from all module packages
│   │   ├── pages/
│   │   │   ├── login.component.ts         # Keycloak redirect
│   │   │   └── not-found.component.ts     # 404 page
│   │   ├── app.routes.ts                  # Module route registry (one line per module)
│   │   ├── app.config.ts                  # Providers (interceptors + module providers)
│   │   └── app.component.ts               # Root component
│   ├── assets/
│   ├── environments/
│   │   ├── environment.ts                 # API base URL, Keycloak config (dev)
│   │   └── environment.prod.ts
│   └── styles.scss                        # Global styles + Angular Material theme
├── angular.json
├── tsconfig.json
├── package.json                           # Depends on @rpms/shared + all @rpms/mod-* packages
├── Dockerfile
└── .github/workflows/
    └── ci.yml                             # Triggered by module webhook OR manual push
```

### Shell Route Registry

```typescript
// rpms-shell-web/src/app/app.routes.ts
import { Routes } from '@angular/router';
import { authGuard } from '@rpms/shared';
import { LayoutComponent } from './layout/layout.component';

export const routes: Routes = [
  {
    path: '',
    component: LayoutComponent,
    canActivate: [authGuard],
    children: [
      // ═══════════════════════════════════════════════════
      // MODULE PLUG POINTS — add one line to plug a module
      // ═══════════════════════════════════════════════════
      {
        path: 'plantation',
        loadChildren: () => import('@rpms/mod-plantation').then(m => m.PLANTATION_ROUTES),
      },
      {
        path: 'trees',
        loadChildren: () => import('@rpms/mod-tree').then(m => m.TREE_ROUTES),
      },
      {
        path: 'tapping',
        loadChildren: () => import('@rpms/mod-tapping').then(m => m.TAPPING_ROUTES),
      },
      {
        path: 'workforce',
        loadChildren: () => import('@rpms/mod-workforce').then(m => m.WORKFORCE_ROUTES),
      },
      {
        path: 'activities',
        loadChildren: () => import('@rpms/mod-activity').then(m => m.ACTIVITY_ROUTES),
      },
      {
        path: 'attendance',
        loadChildren: () => import('@rpms/mod-attendance').then(m => m.ATTENDANCE_ROUTES),
      },
      // ═══════════════════════════════════════════════════
      // PHASE 2+ — plug future modules here
      // ═══════════════════════════════════════════════════
      // { path: 'finance', loadChildren: () => import('@rpms/mod-finance').then(m => m.FINANCE_ROUTES) },
      // { path: 'processing', loadChildren: () => import('@rpms/mod-processing').then(m => m.PROCESSING_ROUTES) },

      { path: '', redirectTo: 'plantation', pathMatch: 'full' },
    ],
  },
  {
    path: 'login',
    loadComponent: () => import('./pages/login.component').then(m => m.LoginComponent),
  },
  { path: '**', redirectTo: '' },
];
```

### Shell Navigation Registry

```typescript
// rpms-shell-web/src/app/layout/nav-registry.ts
import { NavItem } from '@rpms/shared';

// Import nav items from each plugged module
import { PLANTATION_NAV_ITEMS } from '@rpms/mod-plantation';
import { TREE_NAV_ITEMS } from '@rpms/mod-tree';
import { TAPPING_NAV_ITEMS } from '@rpms/mod-tapping';
import { WORKFORCE_NAV_ITEMS } from '@rpms/mod-workforce';
import { ACTIVITY_NAV_ITEMS } from '@rpms/mod-activity';
import { ATTENDANCE_NAV_ITEMS } from '@rpms/mod-attendance';

// Plug/unplug modules by adding/removing entries from this array
export const ALL_NAV_ITEMS: NavItem[] = [
  ...PLANTATION_NAV_ITEMS,
  ...TREE_NAV_ITEMS,
  ...TAPPING_NAV_ITEMS,
  ...WORKFORCE_NAV_ITEMS,
  ...ACTIVITY_NAV_ITEMS,
  ...ATTENDANCE_NAV_ITEMS,
];
```

### Shell App Config

```typescript
// rpms-shell-web/src/app/app.config.ts
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import {
  jwtInterceptor,
  errorInterceptor,
  loadingInterceptor,
} from '@rpms/shared';
import { routes } from './app.routes';

// Module-specific providers (plug/unplug here)
import { PLANTATION_PROVIDERS } from '@rpms/mod-plantation';
import { TREE_PROVIDERS } from '@rpms/mod-tree';
import { TAPPING_PROVIDERS } from '@rpms/mod-tapping';
import { WORKFORCE_PROVIDERS } from '@rpms/mod-workforce';
import { ACTIVITY_PROVIDERS } from '@rpms/mod-activity';
import { ATTENDANCE_PROVIDERS } from '@rpms/mod-attendance';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(
      withInterceptors([jwtInterceptor, errorInterceptor, loadingInterceptor])
    ),
    provideAnimationsAsync(),

    // Module providers
    PLANTATION_PROVIDERS,
    TREE_PROVIDERS,
    TAPPING_PROVIDERS,
    WORKFORCE_PROVIDERS,
    ACTIVITY_PROVIDERS,
    ATTENDANCE_PROVIDERS,
  ],
};
```

### Module Public API Contract

Each module Angular library exports exactly these items:

```typescript
// @rpms/mod-{module}/src/public-api.ts
// This is the ONLY surface the shell sees — module internals are private

export { {MODULE}_ROUTES } from './lib/{module}.routes';
export { {MODULE}_NAV_ITEMS } from './lib/{module}.nav';
export { {MODULE}_PROVIDERS } from './lib/{module}.providers';

// Optional: embeddable widgets for cross-module dashboards
export { YieldSummaryCardComponent } from './lib/components/yield-summary-card.component';
```

### Cross-Module Widget Embedding

Modules can export lightweight components for use in other module dashboards:

```typescript
// In plantation dashboard — embedding tapping module's yield card
import { YieldSummaryCardComponent } from '@rpms/mod-tapping';

@Component({
  selector: 'rpms-plantation-dashboard',
  standalone: true,
  imports: [YieldSummaryCardComponent],
  template: `
    <div class="dashboard-grid">
      <rpms-field-overview-card [plantationId]="plantationId()" />
      <rpms-clone-distribution-card [plantationId]="plantationId()" />
      <!-- Cross-module widget -->
      <rpms-yield-summary-card [plantationId]="plantationId()" />
    </div>
  `,
})
export class PlantationDashboardComponent { /* ... */ }
```

---

## Android Shell Composition

### rpms-shell-android Structure

```
rpms-shell-android/
├── app/
│   ├── src/main/kotlin/com/rpms/app/
│   │   ├── RpmsApplication.kt                # Application class + Koin DI setup
│   │   ├── MainActivity.kt                   # Single activity host
│   │   ├── navigation/
│   │   │   ├── RpmsNavHost.kt                # Composes module nav graphs
│   │   │   └── BottomNavBar.kt               # Bottom navigation items from modules
│   │   ├── ui/theme/                          # Material 3 theme
│   │   └── di/                                # Koin modules for app-level deps
│   ├── src/main/res/
│   └── AndroidManifest.xml
├── app/build.gradle.kts                       # Module dependencies
├── settings.gradle.kts
└── .github/workflows/ci.yml
```

### Module Navigation Composition

```kotlin
// rpms-shell-android/app/.../navigation/RpmsNavHost.kt
@Composable
fun RpmsNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = "plantation") {
        // ═══ Module plug points — add one call to plug a module ═══
        plantationNavGraph(navController)   // from com.rpms:mod-plantation-kmp
        treeNavGraph(navController)         // from com.rpms:mod-tree-kmp
        tappingNavGraph(navController)      // from com.rpms:mod-tapping-kmp
        workforceNavGraph(navController)    // from com.rpms:mod-workforce-kmp
        activityNavGraph(navController)     // from com.rpms:mod-activity-kmp
        attendanceNavGraph(navController)   // from com.rpms:mod-attendance-kmp
        // Phase 2+ modules plug in here
    }
}
```

### Module Navigation Graph Example

```kotlin
// rpms-mod-tapping/kmp-feature/androidMain/.../ui/TappingNavGraph.kt
fun NavGraphBuilder.tappingNavGraph(navController: NavHostController) {
    navigation(startDestination = "tapping/dashboard", route = "tapping") {
        composable("tapping/dashboard") {
            TappingDashboardScreen(navController)
        }
        composable("tapping/tasks") {
            TaskListScreen(navController)
        }
        composable("tapping/tasks/{taskId}",
            arguments = listOf(navArgument("taskId") { type = NavType.StringType })
        ) { entry ->
            TaskDetailScreen(entry.arguments?.getString("taskId")!!, navController)
        }
        composable("tapping/yield") {
            YieldAnalyticsScreen(navController)
        }
    }
}
```

### Module Gradle Dependencies

```kotlin
// rpms-shell-android/app/build.gradle.kts
dependencies {
    // Platform foundation
    implementation("com.rpms:shared-kmp:1.0.0")

    // Module features — plug/unplug by adding/removing lines
    implementation("com.rpms:mod-plantation-kmp:1.0.0")
    implementation("com.rpms:mod-tree-kmp:1.0.0")
    implementation("com.rpms:mod-tapping-kmp:1.0.0")
    implementation("com.rpms:mod-workforce-kmp:1.0.0")
    implementation("com.rpms:mod-activity-kmp:1.0.0")
    implementation("com.rpms:mod-attendance-kmp:1.0.0")
}
```

---

## Database Ownership Model

### Single Writer, Many Readers

| Module | Framework | Writes To (owns) | Reads From (cross-module) |
|---|---|---|---|
| M1 Plantation | Spring Boot | plantation, division, field, nursery, nursery_clone_distribution, clone_master, plantation_land_use, field_lifecycle_history, annual_area_snapshot | — (foundation) |
| M2 Tree | Spring Boot | tree, tree_row, tree_tag, tree_growth_measurement, tree_panel_history, tree_health_inspection, tree_disease_incident, tree_treatment_record, tree_mortality_record, tree_status_change_log, tree_census_summary | plantation, field, clone_master, nursery, lu_tapping_system (M1) |
| M3 Tapping | Quarkus | tapping_schedule, tapping_task, tapping_task_tree_detail, latex_collection_record, collection_point, latex_quality_test, weather_observation, iot_device, iot_sensor_reading | field (M1), tree (M2), worker (M4) |
| M4 Workforce | Spring Boot | worker, gang, worker_skill, worker_field_assignment, worker_next_of_kin, worker_document, worker_leave, worker_leave_balance, worker_training, worker_pay_structure, worker_safety_incident, worker_status_change_log | plantation, division, field (M1) |
| M5 Activity | Quarkus | daily_work_plan, daily_activity, activity_worker_assignment, activity_material_usage, activity_photo_evidence, supervisor_inspection, inspection_checklist_response, daily_activity_summary | plantation, division, field, nursery (M1), worker, gang (M4), tapping_task (M3) |
| M6 Attendance | Quarkus | attendance_scan_log, daily_attendance, shift_roster, overtime_record, attendance_regularization, monthly_attendance_summary | plantation, division (M1), worker, gang, worker_leave (M4), daily_activity (M5), iot_device (M3) |

### Cross-Module Read Pattern

When a module reads from another module's tables, it uses read-only projection entities:

```java
// rpms-mod-tapping/backend — read-only projection of M4's worker table
@Entity
@Table(name = "worker")
@Immutable  // Hibernate: never generates UPDATE/INSERT for this entity
public class WorkerReadProjection {
    @Id
    private Integer workerId;
    private String employeeCode;
    private String fullName;
    private String workerStatus;
    // Only the fields needed for tapping operations — not the full worker entity
}
```

### Database Permission Enforcement

Each module's service account has granular PostgreSQL permissions:

```sql
-- Platform service account (api-gateway, notification, reporting)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rpms_platform;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO rpms_platform;

-- Module 3: Tapping service
GRANT SELECT, INSERT, UPDATE, DELETE ON tapping_schedule, tapping_task, tapping_task_tree_detail,
  latex_collection_record, collection_point, latex_quality_test, weather_observation,
  iot_device, iot_sensor_reading TO rpms_tapping;
GRANT SELECT ON plantation, division, field, tree, worker, gang TO rpms_tapping;  -- read-only cross-module

-- Module 6: Attendance service
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance_scan_log, daily_attendance, shift_roster,
  overtime_record, attendance_regularization, monthly_attendance_summary TO rpms_attendance;
GRANT SELECT ON plantation, division, worker, gang, worker_leave, daily_activity, iot_device TO rpms_attendance;
```

---

## Flyway Migration Strategy

### Prefix Convention

| Prefix Range | Owner Repository | Example Files |
|---|---|---|
| V0_001 – V0_999 | rpms-platform | V0_001__extensions.sql, V0_002__shared_lookups.sql |
| V1_001 – V1_999 | rpms-mod-plantation | V1_001__create_plantation.sql, V1_002__create_division.sql |
| V2_001 – V2_999 | rpms-mod-tree | V2_001__create_tree.sql, V2_002__create_tree_tag.sql |
| V3_001 – V3_999 | rpms-mod-tapping | V3_001__create_tapping_schedule.sql, V3_002__create_tapping_task.sql |
| V4_001 – V4_999 | rpms-mod-workforce | V4_001__create_worker.sql, V4_002__create_gang.sql |
| V5_001 – V5_999 | rpms-mod-activity | V5_001__create_daily_work_plan.sql, V5_002__create_daily_activity.sql |
| V6_001 – V6_999 | rpms-mod-attendance | V6_001__create_scan_log.sql, V6_002__create_daily_attendance.sql |

### Migration Execution Order

Flyway processes migrations in version order. The dependency chain is respected naturally:

```
V0_001 → V0_002 → V0_003 → V0_004     (platform: extensions, lookups, views, triggers)
V1_001 → V1_002 → V1_003 ...           (plantation tables)
V2_001 → V2_002 ...                     (tree tables — depends on M1 tables existing)
V3_001 → V3_002 ...                     (tapping tables — depends on M1 + M2)
V4_001 → V4_002 ...                     (workforce tables — depends on M1)
V5_001 → V5_002 ...                     (activity tables — depends on M1 + M3 + M4)
V6_001 → V6_002 ...                     (attendance tables — depends on M1 + M3 + M4 + M5)
```

### How Modules Access All Migrations

Each module's Flyway configuration includes both its own migrations and the platform migrations:

```yaml
# rpms-mod-tapping/backend/src/main/resources/application.yml
spring:
  flyway:
    locations:
      - classpath:db/platform     # V0_xxx from rpms-platform (pulled as Maven dependency)
      - classpath:db/migration    # V3_xxx from this module's own migrations
    baseline-on-migrate: true
```

For local development, all migrations run when starting any service. In staging/production, Flyway's checksum mechanism ensures each migration runs exactly once regardless of which service applies it first.

---

## CI/CD Pipeline per Module

### GitHub Actions Workflow

```yaml
# rpms-mod-{module}/.github/workflows/ci.yml
name: '{Module} Module CI/CD'

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  JAVA_VERSION: '21'
  NODE_VERSION: '20'
  REGISTRY: ghcr.io

jobs:
  # ══════════════════════════════════════
  # STAGE 1: Build + Test (3 parallel jobs)
  # ══════════════════════════════════════

  backend:
    name: 'Backend Build + Test'
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:16-3.4
        env:
          POSTGRES_DB: rpms_test
          POSTGRES_USER: rpms
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: 'maven'

      - name: Configure GitHub Packages Maven
        run: |
          mkdir -p ~/.m2
          cat > ~/.m2/settings.xml << 'EOF'
          <settings>
            <servers>
              <server>
                <id>github</id>
                <username>${{ github.actor }}</username>
                <password>${{ secrets.GITHUB_TOKEN }}</password>
              </server>
            </servers>
          </settings>
          EOF

      - name: Build + Test
        working-directory: backend
        run: mvn verify -Dquarkus.test.profile=ci

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: backend-test-results
          path: backend/target/surefire-reports/

  angular-lib:
    name: 'Angular Library Build + Test'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          registry-url: 'https://npm.pkg.github.com'

      - name: Install + Build + Test
        working-directory: angular-lib
        run: |
          npm ci
          npx ng lint
          npx ng build
          npx ng test --watch=false --browsers=ChromeHeadless
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  kmp-feature:
    name: 'KMP Feature Build + Test'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: 'gradle'

      - name: Build + Test
        working-directory: kmp-feature
        run: |
          ./gradlew build
          ./gradlew testDebugUnitTest

  # ══════════════════════════════════════
  # STAGE 2: Quality Gates
  # ══════════════════════════════════════

  quality:
    name: 'Quality Gates'
    runs-on: ubuntu-latest
    needs: [backend, angular-lib, kmp-feature]
    steps:
      - uses: actions/checkout@v4

      - name: Validate OpenAPI spec
        run: npx @redocly/cli lint api-contract/*-openapi.yaml

      - name: Validate Avro schemas
        if: hashFiles('api-contract/events/*.avsc') != ''
        run: |
          for schema in api-contract/events/*.avsc; do
            python3 -c "import json; json.load(open('$schema'))"
          done

  # ══════════════════════════════════════
  # STAGE 3: Publish Artifacts (main only)
  # ══════════════════════════════════════

  publish:
    name: 'Publish Artifacts'
    if: github.ref == 'refs/heads/main'
    needs: [quality]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      # Docker image for backend
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: actions/setup-java@v4
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'

      - name: Build + Push Docker image
        working-directory: backend
        run: |
          mvn package -DskipTests
          docker build -t ${{ env.REGISTRY }}/rpms-plantation/{module}-service:${{ github.sha }} .
          docker push ${{ env.REGISTRY }}/rpms-plantation/{module}-service:${{ github.sha }}

      # Angular library → npm
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          registry-url: 'https://npm.pkg.github.com'

      - name: Publish Angular library
        working-directory: angular-lib
        run: |
          npm ci
          npx ng build
          cd dist/rpms-mod-{module}
          npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # KMP artifact → Maven
      - name: Publish KMP feature
        working-directory: kmp-feature
        run: ./gradlew publish
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # ══════════════════════════════════════
  # STAGE 4: Deploy (main only)
  # ══════════════════════════════════════

  deploy:
    name: 'Deploy to Staging'
    if: github.ref == 'refs/heads/main'
    needs: [publish]
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: ArgoCD Sync
        run: |
          argocd app set rpms-{module}-service \
            --parameter image.tag=${{ github.sha }}
          argocd app sync rpms-{module}-service --prune
        env:
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_TOKEN }}
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}

      # Notify shell repos to rebuild with new module version
      - name: Trigger Shell Rebuilds
        run: |
          for repo in rpms-shell-web rpms-shell-android; do
            curl -X POST \
              -H "Authorization: token ${{ secrets.DISPATCH_TOKEN }}" \
              -H "Accept: application/vnd.github.v3+json" \
              -d '{"event_type":"module-updated","client_payload":{"module":"{module}","version":"${{ github.sha }}"}}' \
              https://api.github.com/repos/rpms-plantation/$repo/dispatches
          done
```

### Shell Rebuild Trigger

The shell repos listen for module update events:

```yaml
# rpms-shell-web/.github/workflows/ci.yml
on:
  push:
    branches: [main]
  repository_dispatch:
    types: [module-updated]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://npm.pkg.github.com'

      - name: Update module dependency (if dispatched)
        if: github.event_name == 'repository_dispatch'
        run: |
          MODULE=${{ github.event.client_payload.module }}
          npm install @rpms/mod-${MODULE}@latest
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add package.json package-lock.json
          git commit -m "chore: update @rpms/mod-${MODULE} to latest"
          git push
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - run: npm ci
      - run: npx ng build --configuration=production
      - run: npx ng test --watch=false --browsers=ChromeHeadless

      # Deploy shell to CDN / K8s
      - name: Deploy
        run: |
          docker build -t ghcr.io/rpms-plantation/rpms-shell-web:${{ github.sha }} .
          docker push ghcr.io/rpms-plantation/rpms-shell-web:${{ github.sha }}
          argocd app set rpms-shell-web --parameter image.tag=${{ github.sha }}
          argocd app sync rpms-shell-web
```

---

## Cross-Module Communication Patterns

### Pattern 1: Direct Read (Same Database)

For synchronous queries where a module needs data from another module's tables.

```java
// In rpms-mod-tapping — reading worker name for task display
// The TappingTask entity has: @Column(name = "tapper_id") private Integer tapperId;
// The service reads the worker's name via a read-only projection:

@Immutable
@Entity
@Table(name = "worker")
public class WorkerReadView {
    @Id private Integer workerId;
    private String employeeCode;
    private String fullName;
}

@ApplicationScoped
public class TappingTaskService {
    @Inject WorkerReadViewRepository workerRepo;

    public TappingTaskResponse getTask(Long taskId) {
        TappingTask task = taskRepo.findById(taskId);
        WorkerReadView worker = workerRepo.findById(task.getTapperId());
        return mapper.toResponse(task, worker);
    }
}
```

### Pattern 2: Kafka Events (Async Reactions)

For cross-module side effects that don't need synchronous response.

```java
// In rpms-mod-tapping — publishing event when task completes
@ApplicationScoped
public class TappingEventProducer {
    @Inject @Channel("tapping-task-completed") Emitter<TappingTaskCompleted> emitter;

    public void publishTaskCompleted(TappingTask task) {
        TappingTaskCompleted event = TappingTaskCompleted.newBuilder()
            .setTaskId(task.getTaskId())
            .setFieldId(task.getFieldId())
            .setTapperId(task.getTapperId())
            .setCompletedAt(task.getCompletedAt().toString())
            .setTotalTrees(task.getTotalTrees())
            .build();
        emitter.send(event);
    }
}
```

```java
// In rpms-mod-activity — consuming tapping completion to create activity record
@ApplicationScoped
public class TappingTaskConsumer {
    @Inject DailyActivityService activityService;

    @Incoming("rpms.tapping.task-completed")
    public CompletionStage<Void> onTappingTaskCompleted(TappingTaskCompleted event) {
        activityService.createFromTappingTask(
            event.getTaskId(), event.getFieldId(), event.getTapperId()
        );
        return CompletableFuture.completedFuture(null);
    }
}
```

---

## Migration Plan from Monorepo

### Phase 1: Extract rpms-platform (Week 1–2)

1. Create `rpms-platform` repo
2. Copy `shared-libs/` from `rpms-backend`
3. Add `rpms-spatial` shared library (new)
4. Move `api-gateway/` from `rpms-backend`
5. Move `notification-service/` and `reporting-service/` from `rpms-backend`
6. Create `database/migrations/V0_xxx` from shared DDL objects
7. Extract `angular-shared/` from `rpms-mobile/web-dashboard/src/app/shared/`
8. Extract `kmp-shared/` from `rpms-mobile/shared/`
9. Copy `infra/` from `rpms-backend`
10. Configure GitHub Packages publishing for Maven + npm
11. Publish all artifacts as v1.0.0
12. Verify: each artifact builds and publishes successfully

### Phase 2: Extract Module Repos (Week 3–5)

For each module (M1 → M6), sequentially:

1. Create `rpms-mod-{module}` repo from template
2. Copy backend service from `rpms-backend/services/{module}-service/`
3. Update `pom.xml` to depend on platform artifacts (no parent POM reference to monorepo)
4. Extract Angular feature module from `rpms-mobile/web-dashboard/src/app/modules/{module}/` into `angular-lib/`
5. Convert to standalone components + publishable library (ng-package.json)
6. Export `{MODULE}_ROUTES`, `{MODULE}_NAV_ITEMS`, `{MODULE}_PROVIDERS` from `public-api.ts`
7. Extract KMP feature from `rpms-mobile/shared/src/commonMain/kotlin/com/rpms/shared/domain/{module}/` into `kmp-feature/`
8. Create Flyway migrations (V{N}_xxx) from existing DDL
9. Copy OpenAPI spec and Avro schemas to `api-contract/`
10. Create Kubernetes manifests in `k8s/`
11. Configure `.github/workflows/ci.yml`
12. Verify: module builds independently, all tests pass, service starts against shared database

### Phase 3: Create Shell Apps (Week 6)

1. Create `rpms-shell-web` with layout, sidebar, routing, theme
2. Wire up all six `@rpms/mod-*` packages via lazy loading
3. Create `rpms-shell-android` with Compose Navigation host
4. Wire up all six `com.rpms:mod-*-kmp` packages
5. Configure webhook triggers from module repos
6. Full integration testing: all modules load correctly, navigation works, cross-module widgets render

### Phase 4: Decommission Monorepos (Week 7)

1. Archive `rpms-backend` repo (read-only, preserved for git history)
2. Archive `rpms-mobile` repo (read-only, preserved for git history)
3. Update `rpms-design/README.md` to reference new repo structure
4. Update `rpms-design/RPMS_PROJECT_CONTEXT.md` with new architecture
5. Update `rpms-design/architecture/rpms_artifact_storage_strategy.html` to reflect 10-repo structure

---

## Checklist: Plugging a New Module

When adding a Phase 2+ module (e.g., Financial Accounting):

### 1. Create Module Repo

- [ ] Create `rpms-mod-finance` from template
- [ ] Implement backend service (Spring Boot or Quarkus)
- [ ] Create Flyway migrations with prefix V7_xxx
- [ ] Implement Angular library with routes, nav items, providers
- [ ] Implement KMP feature with navigation graph
- [ ] Create OpenAPI spec and Avro event schemas
- [ ] Configure CI/CD pipeline
- [ ] Publish all artifacts

### 2. Update rpms-platform

- [ ] Add gateway route for `/api/finance/**` → `finance-service`
- [ ] Add any new shared lookups to `V0_xxx` migrations (if needed)
- [ ] Add any new cross-module views (if needed)

### 3. Plug into rpms-shell-web (3 lines)

- [ ] Add `@rpms/mod-finance` to `package.json`
- [ ] Add route entry in `app.routes.ts`
- [ ] Add nav items in `nav-registry.ts`

### 4. Plug into rpms-shell-android (2 lines)

- [ ] Add `com.rpms:mod-finance-kmp` to `build.gradle.kts`
- [ ] Add `financeNavGraph(navController)` to `RpmsNavHost.kt`

**Total changes to existing code: 5 lines across 2 shell repos. Zero changes to existing module repos.**
