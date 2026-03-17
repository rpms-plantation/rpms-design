# ADR-001: Use PostgreSQL 16 with PostGIS as the Primary Operational Database

- **Date**: 2026-03-14
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Database engineering, plantation operations domain experts

## Context and Problem Statement

The Rubber Plantation Management System (RPMS) requires a primary operational database to serve six Phase 1 modules and an extensible foundation for future phases. The database must support a wide range of data patterns simultaneously, which makes this decision foundational — every module, every microservice, and every query pattern builds on this choice.

The specific data characteristics that drive this decision are:

- **Spatial data is a first-class concern, not an afterthought.** Plantations are inherently geographic. The schema includes 15+ geometry columns across multiple modules: field boundary polygons (for area calculation and containment queries), individual tree GPS points (millions of trees per large estate), GPS route LineStrings (tapper shift tracking over 6 hours), geofence polygons (for automatic attendance check-in), nursery boundaries, collection point locations, and activity photo geo-tags. Queries like "show me all mature fields within 2km of the factory," "which trees fall inside this disease-affected polygon," and "did this tapper's GPS route stay within the assigned field boundary" are core operational requirements — not edge cases.

- **Relational integrity across 60+ tables with complex cross-module foreign keys.** The six modules form a tightly interconnected domain model. The `worker` table (Module 4) is referenced by `tapping_task.tapper_id` (Module 3), `daily_activity.assigned_worker_id` (Module 5), and `daily_attendance.worker_id` (Module 6). The `field` table (Module 1) is referenced by 20+ foreign keys across all modules. Cascading integrity constraints, self-referencing hierarchies (`worker.reports_to_id`), and generated columns (`worker.full_name`, `worker_leave_balance.remaining_days`) require a mature relational engine.

- **IoT time-series telemetry at high volume.** Smart tapping knives, GPS wearables, rain gauges, and digital scales generate sensor readings that must be ingested at thousands of rows per second during peak tapping hours (04:30–09:00 daily). The `iot_sensor_reading` table is designed with range partitioning by month, and this data must be queryable alongside relational operational data (e.g., "correlate rainfall from the rain gauge with latex yield from the tapping task for the same field and date").

- **Vector embeddings for Gen AI.** The planned AI copilot uses Retrieval Augmented Generation (RAG) over plantation documents, SOPs, and historical reports. This requires storing and querying high-dimensional vector embeddings alongside the operational data they describe.

- **JSONB for flexible AI model outputs.** The `activity_photo_evidence.ai_analysis_result` column stores structured outputs from evolving ML models (photo analysis scores, detected issues, labels). The schema must accommodate semi-structured data that changes shape as AI models improve — without requiring DDL migrations.

- **30 triggers for auto-computation.** The schema relies heavily on server-side trigger functions for auto-calculating yield per tree, dry rubber content from DRC percentages, attendance hours and late detection, material variance, leave balance updates, gang size synchronization, and GPS point generation from latitude/longitude pairs. The trigger engine must be reliable, performant, and support complex procedural logic.

- **Budget sensitivity.** The project starts with a solo developer on a $0/month tooling budget. The database must be free, open-source, and deployable locally via Docker with no licensing costs — now or at scale.

## Decision Drivers

1. **Spatial query capability** — Native geometric operations (containment, distance, intersection, area calculation) on Points, LineStrings, and Polygons
2. **Relational integrity** — Foreign keys, cascades, check constraints, unique constraints, generated columns across 60+ tables
3. **Time-series IoT support** — Efficient ingestion and querying of high-volume sensor data with automatic partitioning and compression
4. **Vector search for AI/RAG** — HNSW or IVFFlat indexes on high-dimensional embeddings for similarity search
5. **Semi-structured data** — JSONB with indexing for flexible AI output storage
6. **Trigger and procedural logic** — Robust PL/pgSQL for 30 auto-computation triggers
7. **Ecosystem and tooling** — ORM support (Hibernate/JPA, Panache), migration tools (Flyway), monitoring, backup
8. **Cost** — $0 licensing, open-source, no per-node or per-core fees
9. **Operational maturity** — Proven at scale, well-documented, active community, predictable release cycle
10. **Extension ecosystem** — Ability to add capabilities (spatial, time-series, vector) without switching databases

## Considered Options

1. **PostgreSQL 16 + PostGIS + TimescaleDB + pgvector** — Open-source relational with spatial, time-series, and vector extensions
2. **MySQL 8 / MariaDB** — Open-source relational database
3. **Microsoft SQL Server** — Commercial relational database with spatial support
4. **MongoDB** — Document-oriented NoSQL database
5. **CockroachDB** — Distributed SQL database with PostgreSQL wire compatibility

## Decision Outcome

**Chosen option: PostgreSQL 16 with PostGIS, TimescaleDB, and pgvector extensions**, because it is the only option that natively addresses all five data patterns (relational, spatial, time-series, vector, semi-structured) within a single database engine, at zero licensing cost, with a mature extension ecosystem that adds capabilities without introducing separate database systems to manage.

The critical insight is that PostgreSQL's extension architecture allows us to use **one database engine with one wire protocol, one connection pool, one backup strategy, one monitoring stack, and one operational team** — while supporting spatial queries (PostGIS), IoT time-series (TimescaleDB), AI vector search (pgvector), and JSONB semi-structured data natively. Every alternative would require introducing at least one additional database system for one or more of these requirements.

### Confirmation

This decision will be confirmed successful if:
- All 6 module DDLs execute without modification on PostgreSQL 16 + PostGIS
- Spatial queries (field containment, distance calculations, geofence intersection) perform within 100ms for typical operational queries
- IoT sensor readings ingest at 1,000+ rows/second via TimescaleDB hypertable with automatic monthly partitioning
- The Gen AI copilot retrieves relevant document embeddings via pgvector similarity search within 200ms
- All 30 triggers execute correctly under concurrent load without deadlocks
- The database runs in a Docker container with less than 1GB memory for development, scaling to managed cloud instances for production

## Pros and Cons of the Options

### PostgreSQL 16 + PostGIS + TimescaleDB + pgvector

PostgreSQL is an advanced open-source relational database with over 35 years of development. PostGIS adds ISO SQL/MM spatial standard compliance. TimescaleDB adds time-series hypertables as a PostgreSQL extension. pgvector adds vector similarity search. All three extensions operate within the same PostgreSQL process, share the same transaction manager, and are queryable in a single SQL statement.

**Pros:**

- **PostGIS is the industry-standard spatial database.** It supports the full OGC Simple Features specification — Points, LineStrings, Polygons, MultiPolygons — with spatial indexes (GiST/SP-GiST) that enable sub-millisecond containment and distance queries. The RPMS schema uses `GEOMETRY(Point, 4326)` for trees and GPS positions, `GEOMETRY(LineString, 4326)` for tapping routes, and `GEOMETRY(Polygon, 4326)` for field boundaries and geofence zones. PostGIS functions like `ST_Contains`, `ST_DWithin`, `ST_Area`, and `ST_Intersection` are directly used in views like `vw_plantation_area_summary`. No other database offers this depth of spatial capability as a native extension.

- **TimescaleDB runs as a PostgreSQL extension, not a separate system.** The `iot_sensor_reading` table is partitioned by month using TimescaleDB hypertables. This means automatic chunk management, transparent compression (10-20× for IoT data), and continuous aggregates — all queryable via standard SQL. Critically, a single JOIN can correlate sensor data with relational data: `SELECT w.rainfall_mm, t.total_yield_kg FROM iot_sensor_reading w JOIN tapping_task t ON ...`. If we used a separate time-series database (InfluxDB, TimescaleDB standalone), this cross-domain query would require application-level data stitching.

- **pgvector enables RAG without a separate vector store.** The AI copilot needs to search plantation document embeddings for relevant context. pgvector provides `vector` column type with HNSW indexes for approximate nearest neighbor search. Embeddings live alongside the documents they describe, in the same transaction boundary. No need for Pinecone, Weaviate, or Milvus — eliminating a separate system to deploy, secure, back up, and monitor.

- **JSONB with GIN indexes handles semi-structured AI outputs.** The `ai_analysis_result` column in `activity_photo_evidence` stores ML model output as JSONB. PostgreSQL can index specific JSONB paths (`CREATE INDEX ON ... USING GIN (ai_analysis_result jsonb_path_ops)`), enabling queries like "find all photos where AI detected bark disease with confidence > 0.8" without schema changes when the model output format evolves.

- **PL/pgSQL trigger engine is battle-tested.** All 30 RPMS triggers use PL/pgSQL for auto-calculations (yield per tree, dry rubber from DRC, work hours, late detection, leave balance updates, gang size sync, GPS point generation). PostgreSQL's trigger system handles BEFORE/AFTER triggers, row-level and statement-level, with proper transaction isolation. The `fn_calc_attendance_hours()` trigger, for example, computes gross hours, net hours, late minutes, overtime detection, and GPS point generation in a single trigger function — this level of procedural logic would be impossible in MySQL's limited trigger system.

- **Generated columns reduce application complexity.** `worker.full_name` is `GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED`, and `worker_leave_balance.remaining_days` is `GENERATED ALWAYS AS (entitled_days - taken_days - pending_days) STORED`. These are computed by PostgreSQL, not the application — ensuring consistency regardless of which microservice updates the data.

- **Mature ecosystem for Java/Kotlin.** Hibernate 6 with `hibernate-spatial` provides full JPA support for PostGIS geometry types. Spring Data JPA repositories can use `@Query` with spatial functions directly. Quarkus Panache supports PostGIS via the same Hibernate Spatial dependency. Flyway handles schema migrations including PostGIS-specific DDL. PgBouncer provides connection pooling. pgBackRest handles backups. All tools are free and production-proven.

- **Zero licensing cost at any scale.** PostgreSQL is BSD-licensed. There are no per-core, per-node, per-connection, or per-CPU fees. A solo developer pays nothing. An enterprise deployment with read replicas, connection pooling, and managed hosting pays only for compute — not for the database software itself. This is not true for SQL Server, Oracle, or even some "open-source" databases with dual licensing.

- **SRID 4326 (WGS 84) throughout.** All geometry columns in the RPMS schema use SRID 4326, which is the GPS coordinate system. PostGIS handles datum transformations, great-circle distance calculations, and projection operations transparently. This is critical for plantation operations where GPS devices, mobile apps, and mapping tools all produce WGS 84 coordinates.

**Cons:**

- **Operational complexity with multiple extensions.** Running PostgreSQL + PostGIS + TimescaleDB + pgvector in a single instance requires ensuring extension compatibility across versions. Upgrades must verify that all three extensions support the target PostgreSQL version. Mitigated by using the official `timescale/timescaledb-ha` Docker image which bundles PostGIS and pgvector pre-tested.

- **Single-node write scalability limit.** PostgreSQL is not a distributed database. Write throughput is bounded by a single primary node. For RPMS's scale (thousands of tappers, not millions of concurrent users), this is not a practical concern. If write scaling becomes necessary in future phases, read replicas handle query offloading, and PgBouncer handles connection multiplexing. True write distribution would require a migration to CockroachDB or Citus (PostgreSQL extension for distributed tables).

- **TimescaleDB licensing nuance.** TimescaleDB Community Edition is free and covers all features RPMS needs (hypertables, compression, continuous aggregates). The Enterprise Edition adds multi-node and some advanced features behind a commercial license. RPMS uses only Community Edition features, so this is not a cost concern, but it should be documented.

- **pgvector is newer than dedicated vector databases.** pgvector was first released in 2021 and has matured significantly, but dedicated vector databases like Pinecone offer higher query throughput for pure vector workloads. For RPMS's RAG use case (querying thousands of document embeddings, not millions), pgvector's performance is more than sufficient, and the operational simplicity of keeping vectors in PostgreSQL outweighs the marginal performance advantage of a dedicated system.

### MySQL 8 / MariaDB

MySQL is the most widely deployed open-source relational database, known for simplicity and read performance.

**Pros:**

- Widely known, easy to set up, large community, abundant hosting options.
- Adequate for simple CRUD workloads.
- Free and open-source (with caveats for MariaDB vs MySQL licensing).

**Cons:**

- **Spatial support is rudimentary.** MySQL's spatial implementation lacks the depth of PostGIS. No support for geography types (great-circle calculations), limited spatial index performance, and missing advanced functions (no `ST_DWithin` with geography, no spatial aggregates, no raster support). RPMS's 15+ geometry columns with containment, distance, and intersection queries would require significant application-level workarounds.
- **Trigger system is severely limited.** MySQL allows only one trigger per trigger event per table (one BEFORE INSERT, one AFTER INSERT). RPMS's trigger design, which chains multiple computations in a single trigger function and uses conditional logic with DECLARE blocks, would need to be restructured or moved to application code.
- **No generated stored columns with expressions.** MySQL's generated columns cannot reference other tables or use complex expressions like PostgreSQL's `GENERATED ALWAYS AS (...)` with string concatenation and arithmetic.
- **No JSONB equivalent with path indexing.** MySQL's JSON type lacks GIN index support for arbitrary path queries.
- **No native time-series extension.** No TimescaleDB equivalent — IoT data would require manual partitioning management.
- **No vector search extension.** No pgvector equivalent — RAG would require a separate vector database.

### Microsoft SQL Server

SQL Server is Microsoft's commercial relational database with spatial support and enterprise features.

**Pros:**

- Mature spatial support (geography and geometry types).
- Strong enterprise tooling (SSMS, SSIS, SSRS).
- Good Hibernate/JPA support.
- Express Edition is free (with limitations).

**Cons:**

- **Licensing costs at scale.** Standard Edition starts at ~$3,945 per 2-core pack. Enterprise Edition is ~$15,123 per 2-core pack. Express Edition is free but limited to 10GB database size and 1GB memory — RPMS's 60+ tables with IoT telemetry would exceed this quickly.
- **No time-series extension.** No TimescaleDB equivalent. Temporal tables in SQL Server serve a different purpose (row versioning, not IoT ingestion).
- **No vector search.** No pgvector equivalent. Would require Azure Cognitive Search or a separate system.
- **Linux support is secondary.** SQL Server on Linux is supported but the ecosystem (tooling, community, Docker images) is Windows-centric. RPMS's Kubernetes deployment targets Linux containers.
- **Vendor lock-in.** Ties the project to Microsoft's ecosystem and pricing decisions. The $0 budget constraint for the current phase makes this a non-starter.

### MongoDB

MongoDB is a document-oriented NoSQL database known for flexible schemas and horizontal scaling.

**Pros:**

- Flexible schema — no DDL migrations for document structure changes.
- Native JSONB-like document storage.
- Horizontal scaling via sharding.
- Geospatial indexes support point and polygon queries.

**Cons:**

- **No relational integrity.** RPMS's 60+ tables with 100+ foreign key relationships, cascading constraints, and cross-module referential integrity cannot be enforced at the database level. Every constraint becomes application-level validation — increasing bug surface area dramatically.
- **No trigger equivalents.** MongoDB's change streams are not equivalent to PostgreSQL triggers for synchronous, transactional auto-computation. All 30 RPMS triggers would move to application code.
- **Spatial support is basic.** MongoDB supports 2dsphere indexes for point-in-polygon and near queries, but lacks the full OGC standard support of PostGIS. No LineString route operations, no polygon intersection/union, no spatial aggregates, no SRID-aware projections.
- **No ACID transactions across collections (historically).** MongoDB 4.0+ added multi-document transactions, but they carry significant performance overhead and are not recommended for high-throughput writes — exactly the pattern RPMS needs for IoT telemetry and attendance scan logs.
- **No time-series with relational joins.** MongoDB's time-series collections cannot be joined with regular collections in a single query. Correlating IoT sensor data with tapping task data would require multiple round-trips.
- **ORM/JPA incompatibility.** The RPMS backend uses Spring Data JPA and Hibernate Spatial. MongoDB requires Spring Data MongoDB — a completely different repository pattern, query language, and mapping strategy.

### CockroachDB

CockroachDB is a distributed SQL database with PostgreSQL wire protocol compatibility and automatic sharding.

**Pros:**

- PostgreSQL-compatible SQL and wire protocol — most RPMS DDL would work with minimal changes.
- Distributed and horizontally scalable by default.
- Strong consistency across nodes.
- Free Core edition available.

**Cons:**

- **No PostGIS.** CockroachDB has basic spatial types and indexes but does not support the full PostGIS function library. RPMS's `ST_Contains`, `ST_DWithin`, `ST_MakePoint`, `ST_SetSRID`, `ST_Area` usage would require rewriting or removing spatial logic.
- **No TimescaleDB.** Time-series hypertables, compression, and continuous aggregates are PostgreSQL-specific extensions that don't run on CockroachDB.
- **No pgvector.** Vector similarity search is not supported.
- **Trigger limitations.** CockroachDB supports a subset of PostgreSQL triggers. Complex PL/pgSQL functions with DECLARE blocks, conditional logic, and cross-table updates (as used in RPMS's 30 triggers) may not execute correctly.
- **Operational overhead for solo developer.** CockroachDB is designed for multi-node distributed deployment. Running it locally for development is heavier than a single PostgreSQL container. The distributed features are unnecessary for RPMS's current scale.
- **Over-engineered for current needs.** RPMS serves plantations with hundreds to thousands of workers, not millions of concurrent users. PostgreSQL's single-node performance with read replicas is more than sufficient, and the operational simplicity of a single PostgreSQL instance outweighs CockroachDB's distributed capabilities.

## Decision Matrix

| Criterion (Weight) | PostgreSQL + Extensions | MySQL 8 | SQL Server | MongoDB | CockroachDB |
|---|---|---|---|---|---|
| Spatial queries (High) | ★★★★★ | ★★☆☆☆ | ★★★★☆ | ★★★☆☆ | ★★★☆☆ |
| Relational integrity (High) | ★★★★★ | ★★★★☆ | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Time-series IoT (High) | ★★★★★ | ★★☆☆☆ | ★★☆☆☆ | ★★★☆☆ | ★★☆☆☆ |
| Vector search / AI (Medium) | ★★★★☆ | ★☆☆☆☆ | ★☆☆☆☆ | ★★☆☆☆ | ★☆☆☆☆ |
| JSONB / semi-structured (Medium) | ★★★★★ | ★★★☆☆ | ★★★☆☆ | ★★★★★ | ★★★★☆ |
| Trigger / procedural logic (High) | ★★★★★ | ★★☆☆☆ | ★★★★☆ | ★☆☆☆☆ | ★★★☆☆ |
| Java/Kotlin ORM ecosystem (High) | ★★★★★ | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★★★☆ |
| Cost (High) | ★★★★★ | ★★★★★ | ★★☆☆☆ | ★★★★★ | ★★★★☆ |
| Operational maturity (Medium) | ★★★★★ | ★★★★★ | ★★★★★ | ★★★★☆ | ★★★☆☆ |
| Single-engine simplicity (High) | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ |
| **Weighted Score** | **Highest** | **Low** | **Mid-Low** | **Low** | **Mid** |

## Extension Deployment Strategy

The three PostgreSQL extensions will be deployed as follows:

| Extension | Version | Docker Image | RPMS Usage |
|---|---|---|---|
| **PostGIS** | 3.4+ | `postgis/postgis:16-3.4` | 15+ geometry columns, spatial indexes, ST_* functions across all 6 modules |
| **TimescaleDB** | 2.x CE | `timescale/timescaledb-ha:pg16` | `iot_sensor_reading` hypertable with monthly partitioning, compression, continuous aggregates |
| **pgvector** | 0.7+ | Included in `timescaledb-ha` | `vector` columns for RAG embeddings, HNSW indexes for similarity search |

The `timescale/timescaledb-ha` Docker image bundles PostgreSQL 16, PostGIS, and pgvector in a single pre-tested image — eliminating extension compatibility concerns for development and production.

## Database-per-Service Strategy

While all six modules share a single PostgreSQL instance, each microservice owns its schema through **schema-level isolation**:

```
rpms (database)
├── plantation_schema    — owned by Plantation Service
├── tree_schema          — owned by Tree Service
├── tapping_schema       — owned by Tapping Service
├── workforce_schema     — owned by Workforce Service
├── activity_schema      — owned by Activity Service
└── attendance_schema    — owned by Attendance Service
```

Cross-module reads use Debezium CDC (Change Data Capture) to stream changes to Kafka, which consuming services materialize into their own read models. Direct cross-schema foreign keys exist at the database level (as designed in the DDLs) but application-level access respects service boundaries.

## Consequences

### Positive

- A single database engine serves all five data patterns (relational, spatial, time-series, vector, semi-structured) — no additional databases to deploy, secure, back up, or monitor.
- All 6 module DDLs (60 tables, 39 lookups, 25 views, 30 triggers) execute without modification on PostgreSQL 16 + PostGIS.
- Spatial queries on field boundaries, tree positions, GPS routes, and geofence zones are first-class SQL operations with GiST index performance.
- IoT telemetry is co-located with operational data, enabling single-query correlations (weather ↔ yield, GPS ↔ attendance) that would require application-level stitching with separate databases.
- The entire database stack runs in a single Docker container for local development at under 512MB memory, scaling to managed cloud instances (AWS RDS, Google Cloud SQL, Neon.tech) for production.
- Zero licensing cost at any scale — BSD license with no per-core, per-node, or per-connection fees.

### Negative

- Extension version management adds upgrade complexity. Major PostgreSQL version upgrades must verify PostGIS, TimescaleDB, and pgvector compatibility. Mitigated by using the `timescaledb-ha` image which is tested as a bundle.
- Single-node write throughput is bounded. If RPMS scales to serve hundreds of plantations with millions of concurrent IoT streams, write bottlenecks may emerge. Mitigated by Citus extension (horizontal sharding for PostgreSQL) or PgBouncer connection multiplexing as intermediate steps before considering a distributed database.
- The team must understand PostGIS spatial types, TimescaleDB hypertable concepts, and pgvector indexing — a broader skill set than a plain PostgreSQL deployment. Mitigated by PostgreSQL's excellent documentation and the fact that each extension is optional and additive (the system works without TimescaleDB or pgvector if needed; only PostGIS is required from day one).

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Extension incompatibility on upgrade | Low | Medium | Use `timescaledb-ha` bundled image. Test upgrades in staging before production. |
| Write throughput limit for IoT ingestion | Low | Medium | TimescaleDB compression reduces storage 10-20×. Batch inserts with `COPY` instead of individual `INSERT`. PgBouncer for connection multiplexing. |
| PostGIS unavailable on managed hosting | Very Low | High | All major cloud providers (AWS RDS, Google Cloud SQL, Azure Database for PostgreSQL) support PostGIS natively. Neon.tech and Supabase also support it. |
| pgvector performance insufficient for RAG | Low | Low | RPMS's RAG corpus is thousands of documents, not millions. pgvector with HNSW index handles this scale comfortably. If needed, switch to dedicated vector store later without affecting operational data. |
| Solo developer PostgreSQL expertise gap | Low | Medium | PostgreSQL has the most extensive documentation of any open-source database. Active community on Stack Overflow, PostgreSQL mailing lists, and Reddit. |

## Links

- **Related ADRs**: ADR-002 (Spring Boot + Quarkus — ORM integration with PostgreSQL), ADR-003 (Kafka — Debezium CDC from PostgreSQL WAL), ADR-004 (Angular — spatial visualization of PostGIS data)
- **Design artifacts**: [`rpms-design/database/`](../../database/) — All 6 module DDLs designed for PostgreSQL 16 + PostGIS
- **PostgreSQL 16 documentation**: https://www.postgresql.org/docs/16/
- **PostGIS documentation**: https://postgis.net/documentation/
- **TimescaleDB documentation**: https://docs.timescale.com/
- **pgvector documentation**: https://github.com/pgvector/pgvector
- **Docker image**: `timescale/timescaledb-ha:pg16` (bundles PostgreSQL + PostGIS + pgvector)
