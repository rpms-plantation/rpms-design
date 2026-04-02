# Continue with Next Priority Task

Determine the highest-priority incomplete task and begin working on it.

## Step 1 — Scan current state

Run the same scan as `/status` (check all artifact locations) but silently — don't output the full report.

## Step 2 — Apply priority rules

Follow this strict priority order. Within each category, follow module dependency order: **M1 → M2 → M4 → M3 → M5 → M6**.

### Priority 1: API Contracts (OpenAPI)
If any module is missing its OpenAPI spec, generate it next.
Order: M1 → M2 → M4 → M3 → M5 → M6

### Priority 2: Avro Event Schemas
If any module's events from the catalog are missing .avsc files, generate them next.
Order: common/EventMetadata first, then M1 → M2 → M4 → M3 → M5 → M6

### Priority 3: Flyway Migrations
If any module's DDL hasn't been split into Flyway scripts, do it next.
Order: V0 (platform) first, then V1 → V2 → V4 → V3 → V5 → V6

### Priority 4: Keycloak Realm Design
If `docs/security/keycloak-realm-design.md` doesn't exist, design it next.

### Priority 5: Module Documentation
If any module's `database/module-N-*/README.md` is missing, generate it next.

### Priority 6: Domain Model
If `domain-model/` is empty, create bounded context map and glossary.

### Priority 7: Wireframes
If `wireframes/` is empty, start with the module that has the most complete API contract.

### Priority 8: Cross-Validation
If all artifacts above exist, run `/validate` to check consistency.

## Step 3 — Announce and begin

Output a brief message:
```
Next task: {what} for {which module}
Reason: {why this is highest priority}
Dependencies satisfied: {what prerequisites are complete}
Starting now...
```

Then immediately begin the task using the appropriate command logic (`/api-contract`, `/avro-event`, `/flyway`, etc.).
