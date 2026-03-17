# ADR-002: Use Spring Boot 3 and Quarkus Hybrid Strategy for Backend Microservices

- **Date**: 2026-03-14
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Backend engineering, DevOps, plantation operations domain experts
- **Related**: ADR-001 (PostgreSQL + PostGIS), ADR-003 (Apache Kafka), ADR-004 (Angular)

## Context and Problem Statement

The Rubber Plantation Management System (RPMS) Phase 1 requires eight backend microservices: six domain services (one per module) plus two cross-cutting services (Notification and Reporting). These services have fundamentally different runtime characteristics, and the framework choice must account for both profiles rather than forcing a single framework onto workloads it wasn't optimized for.

The services fall into two distinct categories based on their operational patterns:

**Category A — Stable CRUD with moderate, predictable load:**

- **Plantation Service (M1)** — Field records, land use, divisions, nurseries, clone management. Primarily CRUD operations with occasional PostGIS spatial queries. Traffic is low and predictable — managers and supervisors updating records during office hours. Data changes infrequently (field boundaries don't move daily).
- **Tree Service (M2)** — Individual tree lifecycle, growth measurements, disease tracking. High read volume during NFC scans (tree profile lookup is the critical path), but writes are moderate — growth measurements are recorded periodically, not continuously. Redis caching handles the read hot path.
- **Workforce Service (M4)** — Worker registration, skills, leave management, training, pay structures. Classic enterprise CRUD with approval workflows. Traffic follows office hours. Integration with Keycloak for user provisioning requires the mature Spring Security ecosystem.
- **Notification Service** — Push notifications, SMS, email. Consumes Kafka events and dispatches through Firebase FCM, Twilio, and SMTP. Moderate throughput, not latency-critical.
- **Reporting Service** — Pre-aggregated views, scheduled rollups (daily yield, monthly attendance), export to Excel/PDF via JasperReports. Batch-oriented, runs on schedules rather than real-time request pressure.

**Category B — High-throughput, event-driven, burst-heavy:**

- **Tapping Service (M3)** — The operational heart of the system. During peak tapping hours (04:30–09:00 daily), every tapper submits task completions, NFC tree scan records, latex collection weights, and quality test results. IoT smart knives stream cut angle/depth telemetry. This service must ingest thousands of events per minute during a concentrated 4.5-hour window, then scale back down for the remaining 19.5 hours.
- **Activity Service (M5)** — Field workers log activities throughout the day: start/stop times, GPS routes (continuous LineString updates), photo uploads, material usage, inspection results. Write-heavy with photo processing (upload to MinIO, trigger AI analysis). Multiple concurrent users updating simultaneously from field locations.
- **Attendance Service (M6)** — The highest event rate in the system. During morning muster (04:00–05:00), every worker on the plantation scans in via biometric, NFC badge, GPS geofence, or mobile app — all within a 30-60 minute window. The `attendance_scan_log` table receives the raw event flood. Each scan triggers real-time computation: work hour calculation, late detection, overtime detection, geofence verification. A single plantation with 500 workers generates 500+ scan events in under an hour, with each event requiring trigger-equivalent processing.

The framework decision must optimize for both categories without over-engineering the stable services or under-powering the burst-heavy ones. Additionally, the solo developer building this system must be able to work productively across both frameworks without excessive cognitive switching.

## Decision Drivers

1. **Container startup time** — Burst-heavy services need to scale from 0 or from few replicas to many within seconds during peak windows (04:30 tapping start, 04:00 muster start), then scale back down
2. **Memory footprint per container** — Lower memory means more replicas per Kubernetes node during auto-scaling, which means faster horizontal scale-out at lower cost
3. **Kafka/messaging integration quality** — Event-driven services need first-class reactive Kafka consumer/producer support with backpressure handling
4. **JPA/Hibernate ecosystem maturity** — CRUD services rely on Spring Data JPA, Hibernate Spatial (PostGIS), and the broad Spring ecosystem (Security, Cache, Actuator, MapStruct)
5. **Developer productivity** — Solo developer must be productive in both frameworks without maintaining two entirely different mental models
6. **Java 21 virtual threads** — Both frameworks must leverage Project Loom virtual threads for efficient concurrent I/O without thread pool exhaustion
7. **Reactive programming model** — Burst services benefit from non-blocking reactive pipelines; CRUD services are simpler with imperative blocking code
8. **Native compilation option** — GraalVM native-image compilation for ultra-fast startup (<100ms) on burst services, available if needed
9. **Community and long-term support** — Both frameworks must have active development, predictable releases, and enterprise adoption
10. **Shared code compatibility** — The `rpms-common` shared library (DTOs, events, utilities) must compile and work in both Spring Boot and Quarkus services

## Considered Options

1. **Spring Boot 3 for all services** — Uniform framework, maximum ecosystem consistency
2. **Quarkus for all services** — Uniform framework, optimized for cloud-native and reactive
3. **Spring Boot 3 + Quarkus hybrid** — Spring Boot for Category A, Quarkus for Category B
4. **Micronaut for all services** — Alternative cloud-native framework with compile-time DI

## Decision Outcome

**Chosen option: Spring Boot 3 + Quarkus hybrid**, because it matches each service category to the framework that best serves its runtime characteristics — Spring Boot's mature ecosystem for stable CRUD services and Quarkus's optimized runtime for high-throughput burst services — while maintaining developer productivity through shared Java 21 foundations, compatible libraries (Hibernate, MapStruct, Jackson, Kafka clients), and a common shared library.

### Service-to-Framework Assignment

| Service | Framework | Category | Rationale |
|---|---|---|---|
| plantation-service | Spring Boot 3 | A (CRUD) | PostGIS spatial queries via Hibernate Spatial, low traffic, stable domain |
| tree-service | Spring Boot 3 | A (CRUD) | Redis caching via Spring Cache, high reads but cacheable, disease tracking workflows |
| workforce-service | Spring Boot 3 | A (CRUD) | Keycloak admin integration via Spring Security, approval workflows, complex validation |
| notification-service | Spring Boot 3 | A (CRUD) | Firebase/Twilio SDKs have Spring starters, moderate throughput |
| reporting-service | Spring Boot 3 | A (CRUD) | JasperReports integrates natively with Spring, batch scheduling via @Scheduled |
| tapping-service | Quarkus | B (Burst) | Peak IoT ingestion, reactive Kafka via SmallRye, scales 0→N during tapping hours |
| activity-service | Quarkus | B (Burst) | Write-heavy from field workers, photo upload pipeline, GPS route streaming |
| attendance-service | Quarkus | B (Burst) | Highest event rate (muster scan flood), real-time computation per scan |

### Confirmation

This decision will be confirmed successful if:
- Category A services (Spring Boot) start in under 4 seconds and consume under 400MB memory per container
- Category B services (Quarkus JVM) start in under 1 second and consume under 150MB memory per container
- Category B services scale from 1 to 5 replicas within 30 seconds via Kubernetes HPA during simulated peak load
- The `rpms-common` shared library compiles and functions identically in both Spring Boot and Quarkus services
- A developer can switch between editing a Spring Boot service and a Quarkus service within the same IDE session without significant context-switching overhead
- Quarkus native-image compilation (optional) achieves sub-100ms startup for attendance-service if needed in production

## Pros and Cons of the Options

### Option 1: Spring Boot 3 for All Services

Spring Boot is the most widely adopted Java framework, with a comprehensive ecosystem covering virtually every enterprise integration need. Version 3 runs on Java 21 with virtual thread support, and the Spring ecosystem includes Spring Data JPA, Spring Security, Spring Cache, Spring Cloud (Gateway, Config, Circuit Breaker), Spring for Apache Kafka, and hundreds of community starters.

**Pros:**

- **Maximum ecosystem consistency.** All services use the same dependency injection model (Spring IoC), the same configuration system (application.yml), the same testing framework (Spring Boot Test + MockMvc), and the same build plugin (spring-boot-maven-plugin). A developer navigating any service in the monorepo finds identical structure and patterns.
- **Richest library ecosystem.** Spring Data JPA with Hibernate Spatial for PostGIS, Spring Security with Keycloak adapter, Spring Cache with Redis, Spring for Apache Kafka, Spring Actuator for health/metrics, MapStruct with Spring component model, JasperReports integration — all have first-class Spring starters with auto-configuration. No manual wiring needed.
- **Largest talent pool.** Spring Boot is the dominant Java framework globally. When the team grows, finding Spring Boot developers is significantly easier than finding Quarkus developers.
- **Virtual threads in Spring Boot 3.2+.** Setting `spring.threads.virtual.enabled=true` gives all request-handling threads virtual thread semantics — massive concurrent I/O without thread pool tuning. This partially addresses the scalability gap with reactive frameworks.
- **Mature and predictable.** Spring Boot follows a 6-month release cadence with long-term support. The framework has been production-proven for over a decade. Enterprise adoption is unquestioned.

**Cons:**

- **Startup time of 2-4 seconds.** Spring Boot's classpath scanning, bean initialization, and auto-configuration add overhead at startup. For Category B services that need to scale from 1 to 5 replicas during a sudden muster scan flood (500+ events in 30 minutes), each new replica taking 3+ seconds to become ready means a cumulative 15-second scale-out delay — during which incoming events queue or are dropped.
- **Memory footprint of 250-400MB per instance.** A typical Spring Boot service with JPA, Kafka, Redis, and Actuator consumes 300-400MB of heap. In a Kubernetes cluster with 8GB worker nodes, this allows only 20-26 replicas per node. Quarkus achieves the same functionality at 80-150MB, allowing 53-100 replicas per node — a 2.5-4× density improvement.
- **Reactive programming is bolted on, not native.** Spring WebFlux exists but is a separate programming model from Spring MVC. Mixing reactive and imperative code in the same service is awkward. Most Spring Boot developers default to imperative blocking code, which is fine for Category A but suboptimal for Category B's event-driven pipelines.
- **No native compilation path.** Spring Boot supports GraalVM native-image via Spring Native, but the experience is significantly less mature than Quarkus's native compilation. Many Spring libraries require reflection metadata configuration, and the build time is substantially longer. For the attendance-service where sub-100ms startup could eliminate the scale-out delay entirely, Spring Native is not production-ready enough.
- **Over-provisioning for burst workloads.** To compensate for slow startup, Category B services would need to run more idle replicas at all times (pre-scaled), wasting resources during the 19+ hours per day when tapping isn't active. This increases cloud hosting costs unnecessarily.

### Option 2: Quarkus for All Services

Quarkus is a Kubernetes-native Java framework designed for cloud-native applications. It performs build-time initialization (moving work from runtime to compile time), supports both imperative and reactive programming models natively, and offers GraalVM native-image compilation as a first-class feature. Quarkus uses CDI (Contexts and Dependency Injection) for its component model and SmallRye implementations of MicroProfile specifications.

**Pros:**

- **10× faster startup (JVM mode).** Quarkus achieves 0.3-0.8 second startup in JVM mode by performing classpath scanning, annotation processing, and configuration resolution at build time rather than runtime. Category B services scale out almost instantly.
- **50% less memory.** Build-time optimization eliminates reflection metadata and unused class loading at runtime. A typical Quarkus service with JPA (Panache), Kafka (SmallRye Reactive Messaging), and Redis consumes 60-150MB — half of Spring Boot's footprint.
- **Native compilation is production-grade.** Quarkus was designed from the ground up for GraalVM native-image. Native-compiled services start in 10-50ms and consume 20-50MB. The attendance-service could scale from 0 to handling 500 scan events in under a second.
- **Reactive-first with imperative option.** Quarkus's RESTEasy Reactive supports both reactive (Mutiny) and imperative (blocking) endpoints in the same service. SmallRye Reactive Messaging provides backpressure-aware Kafka consumers. This is ideal for Category B services that process event streams.
- **Dev mode with live reload.** `quarkus:dev` provides instant hot reload without restarting the JVM — faster feedback loop than Spring Boot's DevTools.

**Cons:**

- **Smaller ecosystem than Spring.** While Quarkus supports Hibernate ORM (via Panache), Kafka, Redis, and most common integrations, the ecosystem of community extensions is smaller. JasperReports has no Quarkus extension — it would require manual integration. Firebase Admin SDK, Twilio, and some niche libraries lack Quarkus starters.
- **Hibernate Spatial (PostGIS) support is less documented.** It works — Quarkus uses Hibernate ORM underneath — but the documentation, community examples, and Stack Overflow answers for Quarkus + PostGIS are sparse compared to Spring Boot + Hibernate Spatial. For the Plantation Service's complex spatial queries (`ST_Contains`, `ST_DWithin`, `ST_Area`), Spring Data JPA's `@Query` with spatial functions has more proven patterns.
- **Keycloak integration is different.** Quarkus uses its own OIDC extension (`quarkus-oidc`) rather than Spring Security's Keycloak adapter. The Workforce Service needs Keycloak Admin Client for user provisioning (creating worker accounts when workers are registered) — this integration is more mature in Spring's ecosystem.
- **Smaller developer talent pool.** Quarkus adoption is growing but remains a fraction of Spring Boot's market share. Hiring Quarkus developers is harder, and most Java developers would need ramp-up time.
- **CDI vs Spring DI.** CDI (used by Quarkus) and Spring's IoC container are conceptually similar but syntactically different (`@Inject` vs `@Autowired`, `@ApplicationScoped` vs `@Service`). A shared library designed for one doesn't automatically work in the other without abstraction.

### Option 3: Spring Boot 3 + Quarkus Hybrid (Selected)

Use Spring Boot 3 for Category A services (stable CRUD) and Quarkus for Category B services (high-throughput burst). Share a common library (`rpms-common`) designed to compile in both frameworks by using framework-agnostic Java constructs.

**Pros:**

- **Best runtime for each workload.** Category A services get Spring Boot's rich ecosystem, mature JPA/PostGIS support, and broad library compatibility. Category B services get Quarkus's fast startup, low memory, and reactive Kafka processing. Neither category is compromised.
- **Cost-optimized scaling.** Category B services (Tapping, Activity, Attendance) can scale from 1 replica at idle to 5+ replicas during peak hours in under 5 seconds total (Quarkus starts in <1s per instance). Category A services don't need to scale — they run 1-2 replicas at all times. This reduces cloud hosting costs by not over-provisioning idle replicas for burst workloads.
- **Shared Java 21 foundation.** Both frameworks run on Java 21 with virtual threads. Both use Hibernate ORM for JPA. Both support MapStruct, Jackson, and SLF4J. The `rpms-common` shared library uses plain Java records, interfaces, and annotations that compile in both environments.
- **Compatible Kafka integration.** Spring for Apache Kafka and SmallRye Reactive Messaging both use the same underlying Apache Kafka client library and the same Avro serialization via Confluent Schema Registry. Events produced by a Spring Boot service are consumed by a Quarkus service seamlessly — Kafka doesn't care what framework produced the message.
- **Progressive learning curve.** A solo developer starts with Spring Boot (familiar territory for most Java developers) for the first three services (Plantation, Tree, Workforce). By the time Category B services are built (weeks 6-7 per the roadmap), the developer has established patterns that transfer to Quarkus. The entity model, DTO design, and business logic are identical — only the framework plumbing changes.
- **Native compilation as an option, not a requirement.** Category B services run in Quarkus JVM mode initially (0.3-0.8s startup is already fast enough). If production monitoring reveals that scale-out speed needs improvement, native compilation is available without re-architecting — just change the build command.
- **API Gateway unifies the surface.** Spring Cloud Gateway sits in front of all services. External clients (Angular dashboard, KMP mobile app) make requests to a single gateway endpoint — they never know or care whether the backend service is Spring Boot or Quarkus. The framework choice is an internal implementation detail.

**Cons:**

- **Two frameworks to maintain.** The development team must understand both Spring Boot and Quarkus conventions, build configurations, and debugging approaches. Maven parent POM configuration is more complex with multi-framework modules. CI/CD pipelines need separate build steps for Spring Boot and Quarkus services.
- **Shared library design requires discipline.** The `rpms-common` library must avoid Spring-specific annotations (`@Component`, `@Autowired`) and Quarkus-specific annotations (`@ApplicationScoped`, `@Inject`) in shared code. It uses plain Java records, interfaces, and static utilities — framework-specific wiring happens in each service's own configuration layer.
- **Testing infrastructure duplication.** Spring Boot services use `@SpringBootTest` + `MockMvc` + `@DataJpaTest`. Quarkus services use `@QuarkusTest` + `@QuarkusIntegrationTest` + REST Assured. The testing patterns are different even though the test assertions are similar. Shared test utilities in `rpms-common` must be framework-agnostic.
- **Cognitive switching cost.** Moving between `application.yml` (Spring) and `application.properties` (Quarkus), between `@RestController` and `@Path`, between Spring Data repositories and Panache repositories — requires mental gear-shifting. This cost is real but manageable for a developer who understands both are Java/JPA/Kafka services with different plumbing.

### Option 4: Micronaut for All Services

Micronaut is a cloud-native framework with compile-time dependency injection and AoT (ahead-of-time) processing, offering a middle ground between Spring Boot's ecosystem and Quarkus's performance.

**Pros:**

- Compile-time DI eliminates runtime reflection — fast startup and low memory similar to Quarkus.
- Single framework for all services — no hybrid complexity.
- Good Kafka and Redis support via Micronaut modules.
- GraalVM native-image support.

**Cons:**

- **Smallest ecosystem of the three.** Fewer community libraries, fewer Stack Overflow answers, fewer production case studies than either Spring Boot or Quarkus. PostGIS integration via Hibernate Spatial has minimal Micronaut-specific documentation.
- **Smallest talent pool.** Micronaut developers are rare. Hiring is significantly harder than Spring Boot and even harder than Quarkus.
- **No strategic advantage over the hybrid approach.** Micronaut doesn't outperform Quarkus on startup/memory, and doesn't outperform Spring Boot on ecosystem breadth. It occupies a middle ground that doesn't excel at either extreme.
- **Incompatible with Spring ecosystem.** Unlike Quarkus (which can use some Spring APIs via its Spring compatibility layer), Micronaut uses its own completely separate API surface. Migration from either Spring Boot or Quarkus to Micronaut would be a full rewrite.

## Decision Matrix

| Criterion (Weight) | Spring Boot Only | Quarkus Only | Hybrid (Selected) | Micronaut |
|---|---|---|---|---|
| Startup time for burst services (High) | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★★★☆ |
| Memory efficiency (High) | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★★★☆ |
| Kafka/reactive integration (High) | ★★★☆☆ | ★★★★★ | ★★★★★ | ★★★★☆ |
| JPA/PostGIS ecosystem (High) | ★★★★★ | ★★★☆☆ | ★★★★★ | ★★★☆☆ |
| Keycloak/Security maturity (Medium) | ★★★★★ | ★★★☆☆ | ★★★★★ | ★★★☆☆ |
| Developer productivity (High) | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| Talent availability (Medium) | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★☆☆☆ |
| Framework consistency (Medium) | ★★★★★ | ★★★★★ | ★★★☆☆ | ★★★★★ |
| Native compilation option (Low) | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★★★☆ |
| Cost-optimized scaling (High) | ★★☆☆☆ | ★★★★★ | ★★★★★ | ★★★★☆ |
| **Weighted Score** | **Mid-High** | **Mid-High** | **Highest** | **Mid** |

## Shared Library Strategy

The `rpms-common` shared library is critical to making the hybrid work without code duplication. It is designed with strict framework-agnosticity:

| Component | Contents | Framework-Agnostic Approach |
|---|---|---|
| `rpms-common` | DTOs (Java records), event base classes, exception hierarchy, validation utilities, constants, date/spatial helpers | Plain Java 21 — no Spring or CDI annotations. DTOs are `record` types with Jakarta Validation annotations (shared by both frameworks). |
| `rpms-security` | JWT claims model, role enums, permission constants | Framework-agnostic models. Each service has its own `SecurityConfig` that uses these models with Spring Security or Quarkus OIDC respectively. |
| `rpms-kafka-events` | Avro schemas (.avsc files), generated event classes | Apache Avro is framework-independent. Generated Java classes work identically in Spring Kafka and SmallRye Reactive Messaging. |

**Design rule**: If a class in `rpms-common` needs a framework-specific annotation, it doesn't belong in `rpms-common`. It belongs in the service's own codebase.

## Consequences

### Positive

- Tapping, Activity, and Attendance services start in under 1 second and consume under 150MB — enabling Kubernetes HPA to scale from 1 to 5 replicas within 5 seconds during peak tapping hours, without pre-provisioning idle replicas.
- Plantation, Tree, and Workforce services use Spring Boot's mature PostGIS support (Hibernate Spatial + Spring Data JPA `@Query`), Spring Security's Keycloak integration, and Spring Cache's Redis abstraction — all with first-class auto-configuration and extensive documentation.
- The shared library (`rpms-common`) compiles in both frameworks, ensuring DTOs, events, and utilities are defined once and used everywhere. Changes to a shared event schema propagate to all services via a single Maven dependency update.
- Cloud hosting costs are minimized: Category B services auto-scale during the 4.5-hour tapping window and scale back to 1 replica for the remaining 19.5 hours. Category A services run at 1-2 replicas constantly. No wasted resources.
- The API Gateway (Spring Cloud Gateway) presents a unified API surface — clients are completely unaware of the backend framework serving their request.

### Negative

- Two build configurations, two test patterns, two sets of framework documentation to reference. The Maven parent POM must define separate profiles or modules for Spring Boot and Quarkus builds. CI/CD pipelines need separate build stages.
- The `rpms-common` shared library's framework-agnostic constraint means some convenience features (Spring's `@Cacheable`, Quarkus's `@CacheResult`) cannot be used in shared code — they must be applied at the service layer in each framework's own syntax.
- A new developer joining the project must learn or at least understand both frameworks. This is mitigated by the fact that 80% of the code (entities, business logic, DTOs, mappers, tests) is identical — only the framework plumbing (configuration, DI wiring, REST annotations, Kafka wiring) differs.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Shared library accidentally introduces framework dependency | Medium | Medium | CI build validates that `rpms-common` compiles with both Spring Boot and Quarkus parent POMs. Fail the build if a Spring or CDI import is detected in shared code. |
| Quarkus ecosystem gap for a specific integration | Low | Medium | If a Quarkus extension doesn't exist for a needed library, the plain Java API works (Quarkus runs standard Java). Worst case: manually configure what Spring auto-configures. |
| Developer struggles with framework switching | Medium | Low | Services are built sequentially, not in parallel. The developer works in Spring Boot for 2-3 weeks (M1, M4, M2), then switches to Quarkus for 2 weeks (M3, M5, M6). The switch happens once, not constantly. |
| Spring Boot startup becomes acceptable, making hybrid unnecessary | Low | None | This is a positive outcome. If Spring Boot 4 achieves sub-1s startup via CRaC or improved AOT, the hybrid can be simplified to Spring Boot only — the service boundaries and API contracts remain identical regardless of framework. |
| Quarkus project loses momentum or direction | Very Low | High | Quarkus is backed by Red Hat and has strong community adoption. If it were abandoned, the Quarkus services could be migrated to Spring Boot (same JPA entities, same Kafka events, same business logic — only the plumbing changes). |

## Links

- **Related ADRs**: ADR-001 (PostgreSQL — Hibernate Spatial used in Spring Boot, Panache in Quarkus), ADR-003 (Kafka — Spring Kafka vs SmallRye Reactive Messaging), ADR-004 (Angular — backend framework is invisible to frontend)
- **Design artifacts**: [`rpms-design/architecture/rpms_high_level_architecture.html`](../rpms_high_level_architecture.html) — Layer 5 (Microservices)
- **Spring Boot 3 documentation**: https://docs.spring.io/spring-boot/docs/current/reference/html/
- **Quarkus documentation**: https://quarkus.io/guides/
- **Quarkus vs Spring Boot benchmarks**: https://quarkus.io/blog/quarkus-performance/
- **rpms-common shared library**: [`rpms-backend/shared-libs/rpms-common/`](https://github.com/rpms-plantation/rpms-backend/tree/main/shared-libs/rpms-common)
