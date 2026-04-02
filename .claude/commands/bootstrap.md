Scaffold design artifacts for a new module. Ask me for:
1. Module number (N)
2. Module name
3. Brief description

Then create:
- api-contracts/{module}-service-openapi.yaml (skeleton with shared components)
- api-contracts/events/{ModuleEvent}.avsc (Avro schemas from the event catalog)
- database/migrations/V{N}_001__create_{module}_tables.sql (from the DDL)
- database/migrations/V{N}_002__create_{module}_indexes.sql
- database/migrations/V{N}_003__create_{module}_views.sql
- database/migrations/V{N}_004__create_{module}_triggers.sql
- database/migrations/V{N}_005__seed_{module}_lookups.sql

Follow all conventions from CLAUDE.md.