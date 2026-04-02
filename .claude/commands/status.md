# Project Status Report

Scan the rpms-design repository and generate a current status report of all design artifacts.

## Step 1 — Scan the repository

Check each of these locations for existing artifacts:

### Database Schemas
```
database/module-1-field-records/    → .sql, .html, .mermaid, README.md
database/module-2-tree-records/     → .sql, .html, .mermaid, README.md
database/module-3-tapping-task/     → .sql, .html, .mermaid, README.md
database/module-4-workforce/        → .sql, .html, .mermaid, README.md
database/module-5-daily-activity/   → .sql, .html, .mermaid, README.md
database/module-6-attendance/       → .sql, .html, .mermaid, README.md
database/migrations/                → V0_xxx through V6_xxx
```

### API Contracts
```
api-contracts/                      → {module}-service-openapi.yaml (6 expected)
api-contracts/events/               → Avro .avsc files organized by module
api-contracts/events/topic-registry.yaml
```

### Architecture
```
architecture/architecture-decisions/ → ADR-001 through ADR-00N
architecture/rpms_high_level_architecture.html
architecture/rpms_artifact_storage_strategy.html
architecture/modular-architecture-implementation-guide.md
```

### Other Design Artifacts
```
wireframes/         → UI mockups
domain-model/       → bounded contexts, event storming, glossary
docs/               → NFRs, security architecture, data flow diagrams
```

## Step 2 — Generate the report

Present the status in this format:

```
═══════════════════════════════════════════
  RPMS Design Repository — Status Report
  Generated: {date}
═══════════════════════════════════════════

DATABASE SCHEMAS
  M1 Plantation:  ✅ DDL  ✅ HTML  ✅ Mermaid  ⬜ README
  M2 Tree:        ✅ DDL  ✅ HTML  ✅ Mermaid  ⬜ README
  ...
  Flyway:         ⬜ V0  ⬜ V1  ⬜ V2  ⬜ V3  ⬜ V4  ⬜ V5  ⬜ V6

API CONTRACTS
  M1 OpenAPI:     ✅ plantation-service-openapi.yaml
  M2 OpenAPI:     ⬜ not started
  ...
  Avro Events:    ⬜ not started

ARCHITECTURE
  ADR-001:        ✅ Accepted
  ADR-002:        ✅ Accepted
  ...
  High-Level:     ✅ Complete
  Storage:        ✅ Complete
  Implementation: ✅ Complete

OTHER ARTIFACTS
  Wireframes:     ⬜ not started
  Domain Model:   ⬜ not started
  NFRs:           ⬜ not started
  Security Arch:  ⬜ not started
  Keycloak Realm: ⬜ not started

SUMMARY
  Complete:    XX / YY artifacts
  In Progress: XX
  Not Started: XX

RECOMMENDED NEXT STEPS (in priority order):
  1. {highest priority incomplete artifact}
  2. {next priority}
  3. {next priority}
```

## Step 3 — Priority logic for recommendations

Follow the dependency order from CLAUDE.md:
1. API contracts (OpenAPI) — start with M1, then M2 → M4 → M3 → M5 → M6
2. Avro event schemas — all module events from the catalog
3. Flyway migrations — V0 (platform) first, then V1–V6
4. Keycloak realm + role matrix
5. Domain model / bounded contexts
6. Wireframes / UI mockups
7. NFRs and security architecture

Within each category, follow module dependency order: M1 → M2 → M4 → M3 → M5 → M6
