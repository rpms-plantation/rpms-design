# Analyze Cross-Module Dependencies

Analyze a module's inbound and outbound dependencies — FK references, Kafka events, and shared lookups.

## Step 1 — Identify the module

If a module number was provided, use that. Otherwise ask which module (M1–M6).

## Step 2 — Read the DDLs

Read the target module's DDL, plus the DDLs of all modules it references or is referenced by.

## Step 3 — Analyze three dependency dimensions

### Dimension 1: Database Foreign Keys

**Outbound FKs** (this module's tables reference other modules):
- List each FK: `{this_table}.{column}` → `{other_table}.{column}` (Module N)
- Classify: hard dependency (NOT NULL FK) vs soft dependency (NULLABLE FK)

**Inbound FKs** (other modules' tables reference this module):
- List each FK: `{other_table}.{column}` → `{this_table}.{column}` (Module N)
- These represent this module's "published" entities — changing them has downstream impact

**Shared Lookups** (lookup tables used by multiple modules):
- List each `lu_*` table that this module references
- Note which module (or platform V0) owns the lookup

### Dimension 2: Kafka Events

**Events this module produces** (from the event catalog):
- Event name, topic, partition key, consumers
- Which DDL table/operation triggers the event

**Events this module consumes** (from the event catalog):
- Event name, producing module
- What this module does when it receives the event

### Dimension 3: Shared Library Dependencies

- Which `rpms-common` DTOs does this module need? (e.g., `PlantationRef`, `WorkerRef`)
- Does this module need `rpms-spatial`? (check for geometry columns)
- Does this module need `rpms-security`? (all modules do, but note role-specific needs)

## Step 4 — Generate the dependency report

Output format:

```markdown
# Module {N} — {Name} — Dependency Analysis

## Summary
- Outbound FK dependencies: X tables in Y modules
- Inbound FK dependencies: X tables in Y modules
- Events produced: X
- Events consumed: X
- Module must be deployed AFTER: [list]
- Modules that depend on this module: [list]

## Database Dependencies

### Outbound (this module depends on)
| This Table.Column | → References | Module | Nullable? |
|---|---|---|---|
| ... | ... | ... | ... |

### Inbound (depends on this module)
| Other Table.Column | → References | Module | Nullable? |
|---|---|---|---|
| ... | ... | ... | ... |

### Shared Lookups
| Lookup Table | Owner | Used By This Module In |
|---|---|---|
| ... | ... | ... |

## Event Dependencies

### Produces
| Event | Topic | Trigger | Consumers |
|---|---|---|---|
| ... | ... | ... | ... |

### Consumes
| Event | From Module | Action Taken |
|---|---|---|
| ... | ... | ... |

## Deployment Order Impact
This module requires: {modules} to be deployed first (FK dependencies).
These modules require this module: {modules} (they reference our tables).
Recommended deployment position in sequence: {position}

## Risk Assessment
- Changing `{table}.{column}` would impact: {list of downstream modules}
- This module is a {hub/leaf/intermediate} in the dependency graph
```

## Step 5 — Output

Write to: `docs/dependencies/module-{N}-dependencies.md`

If analyzing all modules, also generate `docs/dependencies/cross-module-matrix.md` with a full NxN dependency matrix.
