# Generate Avro Event Schemas

Generate Apache Avro (.avsc) event schema files for a module's Kafka domain events.

## Step 1 — Identify the module

If a module number or name was provided, use that. Otherwise ask which module (M1–M6).

## Step 2 — Load references

1. Read the event catalog from CLAUDE.md — find all events where this module is the **producer**
2. Read the module's DDL to understand the entity fields available for event payloads
3. Check the topic naming convention: `rpms.{module}.{event-name}`

## Step 3 — Event Catalog Reference

| Event | Producer | Partition Key |
|-------|----------|---------------|
| PlantationCreated | M1 | plantation_id |
| FieldStatusChanged | M1 | field_id |
| TreeStatusChanged | M2 | field_id |
| DiseaseIncidentDetected | M2 | field_id |
| TappingTaskCompleted | M3 | field_id |
| LatexCollected | M3 | field_id |
| QualityTestFailed | M3 | collection_id |
| WorkerStatusChanged | M4 | worker_id |
| LeaveApproved | M4 | worker_id |
| ActivityCompleted | M5 | field_id |
| InspectionFailed | M5 | field_id |
| AttendanceScanReceived | M6 | worker_id |
| DailyAttendanceFinalized | M6 | plantation_id |

## Step 4 — Generate each .avsc file

### Common EventMetadata (create once if not exists)

```json
{
  "type": "record",
  "name": "EventMetadata",
  "namespace": "com.rpms.events.common",
  "fields": [
    { "name": "eventId", "type": "string", "doc": "UUID of this event" },
    { "name": "timestamp", "type": { "type": "long", "logicalType": "timestamp-millis" }, "doc": "Event creation time" },
    { "name": "source", "type": "string", "doc": "Service name that produced the event" },
    { "name": "correlationId", "type": ["null", "string"], "default": null, "doc": "Distributed tracing correlation ID" }
  ]
}
```

### Per-Event Schema Rules

- **Namespace**: `com.rpms.events.{module}` (e.g., `com.rpms.events.tapping`)
- **File name**: `{EventName}.avsc` (PascalCase)
- **Include** `metadata` field of type `com.rpms.events.common.EventMetadata` as the first field
- **Include** the partition key field (e.g., `fieldId`, `workerId`) as a top-level field
- **Cross-module references**: use the entity ID only (e.g., `workerId: int`), never nested objects
- **Timestamps**: use `{ "type": "long", "logicalType": "timestamp-millis" }`
- **UUIDs**: use `{ "type": "string", "logicalType": "uuid" }`
- **Enums**: for status fields, use Avro enum type with all valid values from the DDL
- **Optional fields**: use union `["null", "type"]` with `"default": null`
- **Doc strings**: every field must have a `"doc"` string

### Payload Guidance

Include fields that consumers need to react without calling back to the producer's API:
- Entity IDs (PK + relevant FKs)
- The state change (old status → new status, or the new values)
- Key business fields (e.g., for LatexCollected: `netWeightKg`, `drcPercent`, `dryRubberKg`)
- DO NOT include the entire entity — just the event-relevant fields
- DO NOT include audit fields (`created_by`, `updated_by`) unless the event is specifically about audit

## Step 5 — Output

Create files under: `api-contracts/events/{module}/`
```
api-contracts/events/
├── common/
│   └── EventMetadata.avsc
├── plantation/
│   ├── PlantationCreated.avsc
│   └── FieldStatusChanged.avsc
├── tapping/
│   ├── TappingTaskCompleted.avsc
│   ├── LatexCollected.avsc
│   └── QualityTestFailed.avsc
└── ...
```

Also create or update `api-contracts/events/topic-registry.yaml` with:
```yaml
topics:
  - name: rpms.{module}.{event-name}
    schema: {EventName}.avsc
    partitionKey: {key_field}
    partitions: 6
    replication: 3
    retention: 30d
    compatibility: BACKWARD
    producer: {module}-service
    consumers: [list from event catalog]
```
