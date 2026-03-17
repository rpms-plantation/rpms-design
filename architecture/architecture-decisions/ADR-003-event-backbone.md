# ADR-003: Use Apache Kafka as the Event Backbone with Avro Schema Registry

- **Date**: 2026-03-14
- **Status**: Accepted
- **Deciders**: RPMS Architecture Team
- **Consulted**: Backend engineering, integration architecture, DevOps
- **Related**: ADR-001 (PostgreSQL — Debezium CDC source), ADR-002 (Spring Boot + Quarkus — Kafka client integration)

## Context and Problem Statement

The RPMS microservices architecture (ADR-002) distributes business logic across eight independent services. These services must communicate to fulfill cross-module workflows that span multiple bounded contexts. The communication mechanism is a foundational architectural choice that affects system coupling, reliability, data consistency, scalability, and the ability to add future-phase modules without modifying existing services.

The specific inter-service communication patterns RPMS requires are:

**Event notification (fire-and-forget).** When a tapping task is completed in the Tapping Service, the Activity Service needs to know (to create a corresponding daily_activity record), the Reporting Service needs to know (to update field_yield_daily), and the Notification Service needs to know (to push a completion notification to the supervisor). The Tapping Service should not call these three services directly — it shouldn't even know they exist. It publishes a `TappingTaskCompleted` event, and any interested service subscribes.

**Event-carried state transfer.** When a worker's status changes in the Workforce Service (e.g., from ACTIVE to SUSPENDED), the Tapping Service needs to stop assigning tasks to that worker, the Attendance Service needs to mark future attendance as SUSPENDED, and the Activity Service needs to unassign pending activities. Rather than each service querying the Workforce Service on every request ("is this worker still active?"), the `WorkerStatusChanged` event carries the relevant state, and each consumer materializes a local read model.

**Change Data Capture (CDC).** The Angular management dashboard needs real-time updates when data changes — a new field is added, a tapping task completes, attendance records are finalized. Rather than polling each service's REST API, database changes in PostgreSQL are streamed as events via Debezium, which captures the Write-Ahead Log (WAL) and publishes change events to the backbone. The dashboard subscribes to these events via WebSocket relay.

**Saga coordination.** Cross-service transactions require coordinated, compensatable steps. A "Worker Transfer" saga involves the Workforce Service (update plantation assignment), Attendance Service (close attendance at old plantation, open at new), Tapping Service (unassign from old field tasks, queue for new field assignment), and Activity Service (reassign pending activities). If any step fails, previous steps must be compensated. The event backbone carries saga commands and completion/compensation events between the saga orchestrator (Temporal.io) and the participating services.

**IoT telemetry streaming.** Smart tapping knives, GPS wearables, and environmental sensors produce continuous telemetry at the plantation edge. Apache Camel routes at the edge gateway bridge MQTT (the IoT protocol) to the event backbone, which routes telemetry to the Tapping Service (for task-level aggregation), the Attendance Service (for geofence verification), and the AI services (for anomaly detection). This is high-volume, append-only data that requires partitioned, ordered delivery.

**Event replay and audit.** Rubber plantation operations require traceability — for sustainability certification (FSC, PEFC), regulatory compliance, and dispute resolution. The ability to replay events from a specific point in time ("show me everything that happened to this field's yield records in March") is a compliance requirement, not a nice-to-have. Additionally, when a new Phase 2 module (e.g., Financial Accounting) is deployed, it must be able to consume historical events to bootstrap its state — not just events from the moment it was deployed.

**Future module extensibility.** Phase 2 will add Financial Accounting, Rubber Processing, Supply Chain, and other modules. These new services must integrate with existing modules by subscribing to existing events — without any code changes to the Phase 1 services. The event backbone must support this "open for extension, closed for modification" principle at the infrastructure level.

These patterns collectively require a durable, ordered, partitioned, replayable, schema-governed event streaming platform — not a simple message queue.

## Decision Drivers

1. **Durability and replay** — Events must be persisted and replayable from any point in time, not just consumed once and discarded
2. **Ordering guarantees** — Events for the same entity (same field, same worker, same tree) must be processed in order
3. **Partitioned throughput** — IoT telemetry and attendance scan floods require parallel processing across partitions without ordering conflicts
4. **Schema evolution** — Event schemas will change across phases (new fields added, types modified). Consumers must handle schema evolution without breaking
5. **Exactly-once semantics** — Financial and attendance records cannot tolerate duplicate processing
6. **CDC integration** — Debezium must publish PostgreSQL WAL changes to the backbone natively
7. **Multi-consumer independence** — Multiple services consume the same event independently, at their own pace, without blocking each other
8. **Edge-to-cloud bridging** — MQTT telemetry from plantation edge gateways must flow into the backbone via Apache Camel
9. **Ecosystem compatibility** — Must integrate with Spring Boot (Spring for Apache Kafka), Quarkus (SmallRye Reactive Messaging), Python (AI services), and Debezium
10. **Operational maturity** — Production-proven at scale, well-documented, active community, mature monitoring

## Considered Options

1. **Apache Kafka + Confluent Schema Registry (Avro)** — Distributed event streaming platform with schema governance
2. **RabbitMQ** — Traditional message broker with AMQP protocol
3. **Apache Pulsar** — Distributed pub-sub messaging with tiered storage
4. **Redis Streams** — Lightweight streaming on the existing Redis infrastructure
5. **NATS JetStream** — Cloud-native messaging system with persistence

## Decision Outcome

**Chosen option: Apache Kafka with Confluent Schema Registry using Avro serialization**, because it is the only option that satisfies all seven communication patterns simultaneously — event notification, state transfer, CDC, saga coordination, IoT streaming, event replay, and future extensibility — with production-proven durability, ordering guarantees, exactly-once semantics, and the broadest ecosystem integration across Spring Boot, Quarkus, Python, Debezium, and Apache Camel.

### Confirmation

This decision will be confirmed successful if:
- Events produced by a Spring Boot service (e.g., `WorkerStatusChanged` from workforce-service) are consumed correctly by a Quarkus service (e.g., attendance-service) with Avro deserialization
- Debezium CDC streams PostgreSQL WAL changes from the plantation schema to Kafka topics within 1 second of database commit
- IoT telemetry from the edge gateway (MQTT → Camel → Kafka) flows end-to-end with correct partitioning by device ID
- A new consumer (e.g., future Financial Service) can be added to an existing topic without modifying or redeploying the producing service
- Schema Registry rejects a backward-incompatible schema change (e.g., removing a required field) at registration time, preventing runtime deserialization failures
- Event replay from a specific offset successfully rebuilds a service's read model for disaster recovery testing

## Pros and Cons of the Options

### Apache Kafka + Confluent Schema Registry (Selected)

Apache Kafka is a distributed event streaming platform originally developed at LinkedIn and open-sourced under the Apache Software Foundation. It provides durable, ordered, partitioned log storage with configurable retention. Confluent Schema Registry manages Avro/Protobuf/JSON Schema definitions and enforces compatibility rules across schema versions.

**Pros:**

- **Durable, replayable log.** Kafka topics are append-only logs with configurable retention (time-based or size-based). RPMS can retain events for 30 days, 90 days, or indefinitely. Any consumer can rewind to any offset and replay events. This enables disaster recovery (rebuild service state from events), new module bootstrapping (Financial Service reads historical yield events on first deployment), and audit compliance (replay a specific time range for certification auditors). No other messaging system provides this level of replay capability out of the box.

- **Partitioned ordering.** Kafka guarantees message ordering within a partition. By partitioning on entity keys — `field_id` for tapping events, `worker_id` for attendance events, `device_id` for IoT telemetry — RPMS ensures that all events for the same entity are processed in sequence. Multiple partitions allow parallel processing across entities without ordering conflicts. For example, `tapping-task-events` partitioned by `field_id` means tapping completions for Field-01 and Field-02 are processed in parallel, but events within Field-01 are strictly ordered.

- **Exactly-once semantics (EOS).** Kafka's transactional producer and idempotent consumer support ensures that financial-grade events (latex yield records feeding into payroll calculations, attendance records determining wage computations) are neither duplicated nor lost. Quarkus SmallRye Reactive Messaging and Spring for Apache Kafka both support EOS configuration.

- **Debezium CDC is Kafka-native.** Debezium reads the PostgreSQL WAL and publishes change events directly to Kafka topics. There is no impedance mismatch — Debezium was designed for Kafka. Each database table change becomes a Kafka event with before/after state, enabling real-time dashboard updates, search index synchronization (Elasticsearch), and cross-service materialized views. No other backbone has this level of Debezium integration.

- **Confluent Schema Registry enforces evolution.** Avro schemas are registered before any event is produced. The Registry enforces backward/forward compatibility rules — a producer cannot publish a schema change that would break existing consumers. When Phase 2 adds a new field to `TappingTaskCompleted` (e.g., `sustainability_score`), the Registry ensures the change is backward-compatible so Phase 1 consumers continue working without modification. This is critical for a multi-phase system where modules are deployed independently.

- **Consumer group independence.** Multiple consumer groups (Activity Service, Reporting Service, Notification Service) can all subscribe to the same `tapping-task-events` topic and consume independently. Each group tracks its own offset — if the Reporting Service falls behind, it doesn't block the Activity Service. If a new Financial Service is deployed in Phase 2, it creates a new consumer group and starts consuming from offset 0 (replay) or latest (live only) — without touching any existing consumer.

- **Broadest ecosystem integration.**
  - Spring Boot: `spring-kafka` with `@KafkaListener` and `KafkaTemplate`
  - Quarkus: SmallRye Reactive Messaging with `@Incoming`/`@Outgoing` channel annotations
  - Python: `confluent-kafka-python` for AI services consuming photo analysis events
  - Apache Camel: `camel-kafka` component for edge-to-cloud bridging (MQTT → Kafka)
  - Debezium: Native Kafka Connect source connector
  - Temporal.io: Kafka-based task queue integration for saga events
  - Every component in RPMS's architecture has first-class Kafka support.

- **Proven at hyperscale.** Kafka was designed for LinkedIn's event volumes (trillions of messages per day). RPMS's peak load (a few thousand events per minute during tapping hours) is trivial by comparison. Kafka will never be the bottleneck.

- **Kafka Streams for lightweight processing.** The Anomaly Detection service can use Kafka Streams (a library, not a separate cluster) for stateful stream processing — computing rolling averages, detecting attendance pattern anomalies, and flagging yield outliers — directly on the event stream without a separate processing framework.

**Cons:**

- **Operational complexity.** A Kafka cluster requires Zookeeper (or KRaft in newer versions), broker configuration, topic management, partition rebalancing, and monitoring. For a solo developer, this is overhead compared to simpler messaging systems. Mitigated by using a pre-configured Docker Compose setup for development and a managed Kafka service (Confluent Cloud free tier, or Amazon MSK Serverless) for production.

- **Not designed for request-reply.** Kafka is optimized for async event streaming, not synchronous request-response patterns. If the Angular dashboard needs to query "what are the pending tapping tasks for today," it calls the Tapping Service's REST API — not Kafka. The two patterns coexist: REST for synchronous queries, Kafka for asynchronous events. This dual-protocol approach is standard in event-driven microservices but adds architectural surface area.

- **Schema Registry adds another moving part.** The Confluent Schema Registry is a separate service that must be deployed and monitored alongside Kafka. If the Registry is down, producers cannot publish events with new schemas (existing cached schemas still work). Mitigated by running the Registry as a replicated service with health checks.

- **Learning curve for event-driven patterns.** Developers accustomed to synchronous REST call chains must learn event-driven thinking: eventual consistency, idempotent consumers, event ordering, consumer lag monitoring, dead letter topics for failed processing. This is a paradigm shift, not just a library swap.

- **Disk and memory requirements.** Kafka brokers store event logs on disk. With 30-day retention on all topics and IoT telemetry generating the highest volume, disk usage requires monitoring and capacity planning. Mitigated by enabling log compaction for state events (only keep latest per key) and time-based retention for telemetry events.

### RabbitMQ

RabbitMQ is a traditional message broker implementing the AMQP protocol, known for reliability, routing flexibility, and ease of setup.

**Pros:**

- Simpler to set up and operate than Kafka — single binary, no Zookeeper dependency.
- Excellent routing flexibility — direct, fanout, topic, and header-based exchanges.
- Built-in dead letter queues, retry policies, and message TTL.
- Lower resource footprint for small deployments.

**Cons:**

- **No durable replay.** Once a message is consumed and acknowledged, it is deleted from the queue. There is no concept of consumer offset or log replay. RPMS's requirements for event replay (new module bootstrapping, audit replay, disaster recovery) are fundamentally incompatible with RabbitMQ's consume-and-delete model. RabbitMQ Streams (added in 3.9) partially addresses this, but it's less mature and less widely adopted than Kafka's log model.
- **No native partitioned ordering.** RabbitMQ queues deliver messages in FIFO order to a single consumer, but scaling consumers across multiple queue instances doesn't guarantee entity-level ordering without custom sharding logic. Kafka's partition-key ordering is built into the core.
- **Debezium CDC integration is secondary.** Debezium's primary target is Kafka. While Debezium can publish to RabbitMQ via the outbox pattern or a custom sink, the integration is less mature, less documented, and less performant than the native Kafka Connect pipeline.
- **Schema Registry is not built-in.** No equivalent to Confluent Schema Registry. Schema governance would require a separate tool or manual versioning discipline.
- **Not designed for high-volume streaming.** RabbitMQ excels at task distribution (work queues) and routing, but Kafka excels at high-volume event streaming. IoT telemetry ingestion (thousands of sensor readings per minute) is better served by Kafka's partitioned log than RabbitMQ's queue model.

### Apache Pulsar

Apache Pulsar is a distributed pub-sub messaging platform with tiered storage, multi-tenancy, and geo-replication, originally developed at Yahoo.

**Pros:**

- Tiered storage (hot + cold) reduces cost for long-retention topics.
- Built-in multi-tenancy and namespace isolation.
- Supports both streaming (Kafka-like) and queuing (RabbitMQ-like) patterns.
- Pulsar Functions for lightweight stream processing.

**Cons:**

- **Smallest ecosystem of the three.** Spring Boot has `spring-pulsar` (relatively new), but Quarkus SmallRye Reactive Messaging has limited Pulsar support. Debezium's Pulsar sink connector is experimental. Apache Camel's Pulsar component is less mature than its Kafka component. For RPMS's polyglot service architecture (Spring Boot + Quarkus + Python + Camel + Debezium), Kafka's ecosystem coverage is broader and more battle-tested.
- **Operational complexity exceeds Kafka.** Pulsar requires BookKeeper for storage, ZooKeeper for metadata, and Pulsar brokers for message routing — three separate distributed systems to manage. For a solo developer, this operational burden is significant.
- **Smaller community and fewer production references.** While Pulsar is gaining adoption, the community size, Stack Overflow coverage, tutorial ecosystem, and production case studies are a fraction of Kafka's. Troubleshooting rare issues will take longer.
- **Schema Registry is less mature.** Pulsar has a built-in schema registry, but its compatibility modes and tooling are less mature than Confluent's.

### Redis Streams

Redis Streams is a data structure within Redis that provides append-only log semantics with consumer groups, leveraging the existing Redis infrastructure.

**Pros:**

- RPMS already uses Redis for caching (ADR-001). Redis Streams would eliminate a separate messaging system — one fewer infrastructure component to manage.
- Very low latency for small-scale messaging.
- Simple consumer group model.
- No additional deployment — already running.

**Cons:**

- **No durable persistence guarantee.** Redis Streams are stored in memory with optional disk persistence (RDB snapshots or AOF). If Redis restarts between persistence points, events can be lost. For financial-grade events (yield records, attendance) and audit compliance, this is unacceptable. Kafka's write-ahead log to disk on every produce request provides stronger durability guarantees.
- **No Schema Registry.** No schema governance. Event evolution would be uncontrolled.
- **No Debezium integration.** Debezium cannot publish to Redis Streams natively. CDC would require a custom bridge.
- **No partitioned ordering.** Redis Streams provide global ordering within a single stream, but no entity-key partitioning for parallel processing. Scaling consumers requires manual sharding.
- **Not designed for long retention.** Retaining 30 days of events in Redis memory is prohibitively expensive compared to Kafka's disk-based storage.
- **Ecosystem gaps.** Spring Boot has basic Redis Streams support, but Quarkus SmallRye doesn't have a Redis Streams connector. The Python Kafka client has no Redis Streams equivalent.

### NATS JetStream

NATS JetStream is the persistence layer of the NATS messaging system, providing at-least-once and exactly-once delivery with stream replay.

**Pros:**

- Extremely lightweight — single binary, minimal configuration.
- Fast message delivery with low latency.
- Built-in key-value store and object store.
- Replay from any point in the stream.

**Cons:**

- **Smallest ecosystem for enterprise Java.** No Spring Boot starter. No Quarkus extension. No SmallRye Reactive Messaging integration. RPMS would need custom client wrappers for every service — a significant development effort for a solo developer.
- **No Debezium integration.** CDC from PostgreSQL would require a custom pipeline.
- **No Schema Registry.** Schema governance would be manual.
- **Limited production references at enterprise scale.** NATS JetStream is popular in the cloud-native/Go ecosystem but has minimal adoption in the Java/Spring enterprise world that RPMS targets.
- **Fewer monitoring and operational tools.** Kafka has Confluent Control Center, Kafdrop, AKHQ, Grafana dashboards, and extensive Prometheus metrics. NATS tooling is comparatively sparse.

## Decision Matrix

| Criterion (Weight) | Kafka + Schema Registry | RabbitMQ | Apache Pulsar | Redis Streams | NATS JetStream |
|---|---|---|---|---|---|
| Durable replay (High) | ★★★★★ | ★★☆☆☆ | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Partitioned ordering (High) | ★★★★★ | ★★★☆☆ | ★★★★★ | ★★☆☆☆ | ★★★☆☆ |
| Exactly-once semantics (High) | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★☆☆☆ | ★★★☆☆ |
| Schema evolution (High) | ★★★★★ | ★★☆☆☆ | ★★★★☆ | ★☆☆☆☆ | ★☆☆☆☆ |
| Debezium CDC integration (High) | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★☆☆☆☆ | ★☆☆☆☆ |
| Spring/Quarkus/Python ecosystem (High) | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★★☆☆ | ★★☆☆☆ |
| Camel integration (Medium) | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★☆☆☆ |
| Operational simplicity (Medium) | ★★★☆☆ | ★★★★★ | ★★☆☆☆ | ★★★★★ | ★★★★★ |
| High-volume IoT streaming (High) | ★★★★★ | ★★★☆☆ | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| Community & production maturity (Medium) | ★★★★★ | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★☆☆ |
| **Weighted Score** | **Highest** | **Mid** | **Mid-High** | **Low** | **Low** |

## RPMS Event Catalog (Initial Phase 1)

The following domain events have been identified for Phase 1. Each event is published to a dedicated Kafka topic with Avro serialization.

| Event Name | Producer | Consumer(s) | Partition Key | Trigger |
|---|---|---|---|---|
| `PlantationCreated` | plantation-service | reporting-service | plantation_id | New plantation registered |
| `FieldStatusChanged` | plantation-service | tapping-service, activity-service | field_id | Field transitions (IMMATURE → MATURE, etc.) |
| `TreeStatusChanged` | tree-service | tapping-service, reporting-service | field_id | Tree lifecycle changes (TAPPING, DISEASED, DEAD) |
| `DiseaseIncidentDetected` | tree-service | notification-service, activity-service | field_id | New disease incident recorded with HIGH/CRITICAL severity |
| `TappingTaskCompleted` | tapping-service | activity-service, reporting-service, notification-service | field_id | Tapping task status → COMPLETED or PARTIAL |
| `LatexCollected` | tapping-service | reporting-service, (future) financial-service | field_id | Latex collection record created with net_weight and DRC |
| `QualityTestFailed` | tapping-service | notification-service | collection_id | Quality test result is_within_spec = FALSE |
| `WorkerStatusChanged` | workforce-service | tapping-service, activity-service, attendance-service | worker_id | Worker status transitions (ACTIVE, SUSPENDED, TERMINATED, etc.) |
| `WorkerTransferInitiated` | workforce-service | Temporal saga orchestrator | worker_id | Worker plantation/division reassignment started |
| `LeaveApproved` | workforce-service | attendance-service | worker_id | Leave application approved — pre-populate attendance as absent |
| `AttendanceScanReceived` | attendance-service | anomaly-detection (AI), reporting-service | worker_id | Raw scan event from biometric/NFC/GPS/mobile |
| `DailyAttendanceFinalized` | attendance-service | reporting-service, (future) payroll-service | worker_id | Daily attendance record computed and verified |
| `ActivityCompleted` | activity-service | reporting-service | field_id | Daily activity status → COMPLETED |
| `InspectionFailed` | activity-service | notification-service | field_id | Supervisor inspection overall_rating ≤ 2 |
| `IoTSensorReading` | edge-gateway (Camel) | tapping-service, attendance-service, anomaly-detection (AI) | device_id | Raw sensor telemetry (weather, smart knife, GPS, scale) |
| `AnomalyDetected` | anomaly-detection (AI) | notification-service | entity_id | AI flags attendance fraud, yield anomaly, or pattern deviation |

### Topic Naming Convention

```
rpms.{domain}.{event-name}

Examples:
  rpms.tapping.task-completed
  rpms.workforce.worker-status-changed
  rpms.attendance.scan-received
  rpms.iot.sensor-reading
  rpms.ai.anomaly-detected
```

### Schema Evolution Rules

All topics use **BACKWARD** compatibility mode in Schema Registry:
- New optional fields can be added (with defaults) — existing consumers ignore them
- Fields cannot be removed or renamed — this would break existing consumers
- Field types cannot change — no changing INT to STRING
- When a breaking change is unavoidable, a new topic version is created (e.g., `rpms.tapping.task-completed.v2`) with a migration consumer bridging v1 → v2

## Kafka Deployment Strategy

| Environment | Kafka Setup | Schema Registry | Notes |
|---|---|---|---|
| **Local Dev** | Single broker via Docker Compose (Confluent CP) | Single instance in Docker | `docker-compose.dev.yml` includes Kafka + ZK + SR + Kafdrop UI |
| **Staging** | 3-broker cluster on Kubernetes (Strimzi operator) | 2-instance HA | Strimzi manages broker lifecycle, rolling upgrades |
| **Production** | Managed service (Confluent Cloud or Amazon MSK Serverless) | Managed by provider | Eliminates operational overhead for production Kafka management |
| **Edge Gateway** | No Kafka at edge — Camel routes bridge MQTT → cloud Kafka | N/A | Edge uses MQTT (Mosquitto); Camel publishes to cloud Kafka topics when WAN is available |

## Consequences

### Positive

- All seven inter-service communication patterns (event notification, state transfer, CDC, saga coordination, IoT streaming, event replay, future extensibility) are served by a single infrastructure platform. No need for separate messaging systems for different patterns.
- New Phase 2 modules subscribe to existing topics by creating new consumer groups — zero code changes to Phase 1 services. The Financial Service consumes `LatexCollected` and `DailyAttendanceFinalized` events to compute payroll without the Tapping or Attendance services knowing it exists.
- Debezium CDC streams PostgreSQL changes to Kafka natively, enabling real-time Angular dashboard updates, Elasticsearch search index synchronization, and cross-service materialized views without polling or dual-writes.
- Avro schemas with backward compatibility enforcement prevent breaking changes from reaching production. Schema evolution is managed at the infrastructure level, not through developer discipline alone.
- The event catalog (16 initial events) provides a clear contract between services. When building a new service, the developer consults the catalog to know which events to produce and consume — no need to trace REST call chains.

### Negative

- Kafka adds operational complexity: broker management, topic configuration, partition balancing, consumer lag monitoring, and Schema Registry availability. For a solo developer, this is the most significant overhead introduced by any technology decision. Mitigated by Docker Compose for dev (zero management) and managed Kafka for production (AWS MSK Serverless or Confluent Cloud free tier).
- Eventual consistency is the default model. When the Tapping Service publishes `TappingTaskCompleted`, the Reporting Service's `field_yield_daily` table may take milliseconds to seconds to update. The Angular dashboard must be designed for eventual consistency — showing "last updated X seconds ago" indicators rather than assuming instant propagation.
- Event-driven debugging is harder than tracing synchronous REST calls. When an expected side effect doesn't occur (e.g., attendance wasn't marked as leave despite `LeaveApproved` being published), the developer must trace: was the event produced? Was it consumed? Did the consumer fail? Is there consumer lag? Mitigated by structured logging with correlation IDs, consumer lag monitoring via Grafana, and dead letter topics for failed processing.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Kafka operational overhead for solo developer | High | Medium | Use Docker Compose single-broker for dev (zero management). Use Confluent Cloud free tier or MSK Serverless for production (managed). Only operate a self-managed cluster if cost demands it. |
| Schema Registry becomes a single point of failure | Low | Medium | Producers cache schemas locally after first fetch. If Registry is briefly down, cached schemas allow continued publishing. Deploy Registry as replicated service with health checks. |
| Consumer lag causes stale dashboard data | Medium | Low | Monitor consumer lag via Grafana + Prometheus (kafka_consumer_group_lag metric). Alert if lag exceeds 30 seconds. Dashboard shows "last updated" timestamps so users know data freshness. |
| Event ordering violated across partitions | Low | Low | Partition keys are chosen to match entity boundaries (field_id, worker_id). Events for different entities don't need ordering. Events for the same entity are always in the same partition. |
| Disk usage grows unbounded with IoT telemetry | Medium | Medium | Set retention policy: 7 days for IoT telemetry topics, 30 days for domain events, infinite (compacted) for state events. Monitor disk usage. Enable Kafka log compression (gzip). |
| Breaking schema change deployed accidentally | Low | High | Schema Registry BACKWARD compatibility mode rejects incompatible changes at registration time — before any consumer sees the bad schema. CI pipeline validates schemas against Registry before deployment. |

## Links

- **Related ADRs**: ADR-001 (PostgreSQL — Debezium CDC source), ADR-002 (Spring Boot + Quarkus — Spring Kafka vs SmallRye Reactive Messaging client integration), ADR-006 (Apache Camel — MQTT→Kafka edge bridging)
- **Design artifacts**: [`rpms-design/architecture/rpms_high_level_architecture.html`](../rpms_high_level_architecture.html) — Layer 6 (Integration & Event Backbone)
- **Apache Kafka documentation**: https://kafka.apache.org/documentation/
- **Confluent Schema Registry**: https://docs.confluent.io/platform/current/schema-registry/
- **Debezium PostgreSQL connector**: https://debezium.io/documentation/reference/stable/connectors/postgresql.html
- **Spring for Apache Kafka**: https://docs.spring.io/spring-kafka/reference/
- **SmallRye Reactive Messaging — Kafka**: https://smallrye.io/smallrye-reactive-messaging/latest/kafka/kafka/
- **Avro specification**: https://avro.apache.org/docs/current/specification/
